import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/purpose_bound_consent.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';

class PurposeBoundConsentPage extends StatelessWidget {
  const PurposeBoundConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final profile = state.userProfile;
    final evaluation = profile.localAiConsentEvaluation;
    final receipts = profile.consentReceipts
        .where((receipt) => receipt.featureId == localAiRerankingFeatureId)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(i18n.tr('consent.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              evaluation.granted
                                  ? Icons.check_circle_outline
                                  : evaluation.status ==
                                        PurposeBoundConsentStatus
                                            .blockedIntegrity
                                  ? Icons.gpp_bad_outlined
                                  : Icons.pause_circle_outline,
                              color: evaluation.granted
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                            title: Text(i18n.tr('consent.local_ai_title')),
                            subtitle: Text(
                              i18n.tr(
                                evaluation.granted
                                    ? 'consent.status_granted'
                                    : evaluation.status ==
                                          PurposeBoundConsentStatus.staleNotice
                                    ? 'consent.status_stale'
                                    : evaluation.status ==
                                          PurposeBoundConsentStatus
                                              .blockedIntegrity
                                    ? 'consent.status_blocked'
                                    : 'consent.status_denied',
                              ),
                            ),
                          ),
                          Text(i18n.tr('consent.local_ai_purpose')),
                          const SizedBox(height: 8),
                          for (final activity
                              in LocalAiConsentNotice.processing)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $activity'),
                            ),
                          const SizedBox(height: 8),
                          for (final exclusion
                              in LocalAiConsentNotice.exclusions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $exclusion'),
                            ),
                          const Divider(height: 28),
                          SelectableText(
                            i18n.tr('consent.notice_identity', {
                              'version': '$localAiConsentNoticeVersion',
                              'digest': LocalAiConsentNotice.sha256Digest
                                  .substring(0, 16),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (profile.legacyLocalAiConsentRequested) ...[
                            const SizedBox(height: 10),
                            Text(
                              i18n.tr('consent.legacy_requires_review'),
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('consent-revoke-local-ai'),
                                onPressed: state.isSavingUserProfile
                                    ? null
                                    : () => _record(context, enabled: false),
                                icon: const Icon(Icons.block_outlined),
                                label: Text(i18n.tr('consent.revoke')),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('consent-grant-local-ai'),
                                onPressed:
                                    state.isSavingUserProfile ||
                                        evaluation.status ==
                                            PurposeBoundConsentStatus
                                                .blockedIntegrity
                                    ? null
                                    : () => _record(context, enabled: true),
                                icon: const Icon(Icons.check_outlined),
                                label: Text(i18n.tr('consent.grant')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.tr('consent.history'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (receipts.isEmpty)
                            Text(i18n.tr('consent.history_empty'))
                          else
                            for (final receipt in receipts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text('${receipt.sequence}'),
                                ),
                                title: Text(
                                  i18n.tr(
                                    receipt.decision ==
                                            PurposeBoundConsentDecision.grant
                                        ? 'consent.event_granted'
                                        : 'consent.event_revoked',
                                  ),
                                ),
                                subtitle: SelectableText(
                                  '${receipt.recordedAtUtc.toIso8601String()} · '
                                  '${receipt.source}\n'
                                  '${receipt.receiptId.substring(0, 16)}…',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(BuildContext context, {required bool enabled}) async {
    final i18n = context.appI18n;
    try {
      await context.read<AppState>().setLocalAiConsent(
        enabled,
        source: 'consent_center',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.tr('consent.saved'))));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.tr('consent.save_failed'))));
    }
  }
}
