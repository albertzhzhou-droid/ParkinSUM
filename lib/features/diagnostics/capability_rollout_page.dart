import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/services/capability_rollout_service.dart';
import '../../core/services/services.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/signed_capability_manifest.dart';
import 'package:provider/provider.dart';

class CapabilityRolloutPage extends StatefulWidget {
  const CapabilityRolloutPage({super.key, this.service});

  final CapabilityRolloutService? service;

  @override
  State<CapabilityRolloutPage> createState() => _CapabilityRolloutPageState();
}

class _CapabilityRolloutPageState extends State<CapabilityRolloutPage> {
  final _manifestController = TextEditingController();
  late final CapabilityRolloutService _service;
  late CapabilityRolloutSnapshot _snapshot;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? context.read<Services>().capabilityRolloutService;
    _snapshot = _service.snapshot;
    _reload();
  }

  @override
  void dispose() {
    _manifestController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    final snapshot = await _service.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _busy = false;
    });
  }

  Future<void> _activate() async {
    final input = _manifestController.text.trim();
    if (input.isEmpty) return;
    setState(() => _busy = true);
    final snapshot = await _service.activate(input);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _busy = false;
    });
  }

  Future<void> _fetchAndActivate() async {
    setState(() => _busy = true);
    final result = await _service.fetchAndActivate();
    if (!mounted) return;
    setState(() {
      _snapshot = result.snapshot;
      if (result.fetch.body != null) {
        _manifestController.text = result.fetch.body!;
      }
      _busy = false;
    });
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final snapshot = await _service.clearToConservativeDefaults();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _manifestController.clear();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final manifest = _snapshot.envelope?.manifest;
    final distribution = _service.lastDistributionFetch;
    final distributionCache = _snapshot.distributionCache;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(title: Text(i18n.tr('rollout.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _statusIcon(_snapshot),
                                color: _statusColor(_snapshot),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  i18n.tr('rollout.status_heading'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (_busy)
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _fact(
                            i18n.tr('rollout.status'),
                            _snapshot.activationStatus.name,
                          ),
                          _fact(i18n.tr('rollout.reason'), _snapshot.reason),
                          _fact(
                            i18n.tr('rollout.trust'),
                            _snapshot.trustConfigured
                                ? i18n.tr('rollout.trust_configured')
                                : i18n.tr('rollout.trust_unconfigured'),
                          ),
                          _fact(
                            i18n.tr('rollout.signature'),
                            _snapshot.hasActiveManifest
                                ? i18n.tr('rollout.signature_verified')
                                : i18n.tr('rollout.signature_inactive'),
                          ),
                          _fact(
                            i18n.tr('rollout.distribution'),
                            _service.distributionConfigured
                                ? i18n.tr('rollout.distribution_configured')
                                : _service.distributionConfigurationReason,
                          ),
                          _fact(
                            i18n.tr('rollout.distribution_endpoint'),
                            _service.distributionEndpointLabel ??
                                i18n.tr('rollout.distribution_none'),
                          ),
                          _fact(
                            i18n.tr('rollout.cache_state'),
                            distributionCache == null
                                ? i18n.tr('rollout.cache_none')
                                : i18n.tr('rollout.cache_persisted'),
                          ),
                          if (distributionCache != null) ...[
                            _fact(
                              i18n.tr('rollout.cache_accepted_at'),
                              distributionCache.acceptedAtUtc.toIso8601String(),
                            ),
                            _fact(
                              i18n.tr('rollout.cache_manifest_digest'),
                              distributionCache.manifestSha256,
                            ),
                            _fact(
                              i18n.tr('rollout.fetch_etag'),
                              distributionCache.etag,
                            ),
                          ],
                          if (distribution != null) ...[
                            _fact(
                              i18n.tr('rollout.fetch_status'),
                              '${distribution.status.name} · ${distribution.reason}',
                            ),
                            _fact(
                              i18n.tr('rollout.fetch_etag'),
                              distribution.etag ?? i18n.tr('rollout.etag_none'),
                            ),
                            if (distribution.byteCount != null)
                              _fact(
                                i18n.tr('rollout.fetch_bytes'),
                                '${distribution.byteCount}',
                              ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              key: const ValueKey('rollout-fetch'),
                              onPressed:
                                  _busy || !_service.distributionConfigured
                                  ? null
                                  : _fetchAndActivate,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: Text(i18n.tr('rollout.fetch_activate')),
                            ),
                          ),
                          if (manifest != null) ...[
                            _fact(
                              i18n.tr('rollout.manifest'),
                              '${manifest.manifestId} · #${manifest.sequence}',
                            ),
                            _fact(
                              i18n.tr('rollout.source'),
                              '${manifest.issuer} / ${manifest.keyId}',
                            ),
                            _fact(
                              i18n.tr('rollout.environment'),
                              manifest.environment,
                            ),
                            _fact(
                              i18n.tr('rollout.expiry'),
                              manifest.expiresAtUtc.toIso8601String(),
                            ),
                            _fact(
                              i18n.tr('rollout.rollback'),
                              manifest.rollbackTarget == null
                                  ? i18n.tr('rollout.rollback_none')
                                  : '#${manifest.rollbackTarget!.sequence} · '
                                        '${manifest.rollbackTarget!.manifestSha256.substring(0, 12)}…',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('rollout.capabilities'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final id in SignedCapabilityId.values)
                            _capabilityTile(id),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.tr('rollout.import_title'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(i18n.tr('rollout.import_body')),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('rollout-manifest-input'),
                            controller: _manifestController,
                            enabled: !_busy,
                            minLines: 6,
                            maxLines: 14,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: i18n.tr('rollout.manifest_json'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('rollout-reload'),
                                onPressed: _busy ? null : _reload,
                                icon: const Icon(Icons.refresh),
                                label: Text(i18n.tr('rollout.reload')),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('rollout-clear'),
                                onPressed: _busy ? null : _clear,
                                icon: const Icon(Icons.power_settings_new),
                                label: Text(i18n.tr('rollout.clear')),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('rollout-activate'),
                                onPressed: _busy ? null : _activate,
                                icon: const Icon(Icons.verified_user_outlined),
                                label: Text(i18n.tr('rollout.verify_activate')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('rollout.boundary_title'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(i18n.tr('rollout.boundary_body')),
                          const SizedBox(height: 8),
                          Text(i18n.tr('rollout.distribution_boundary')),
                          const SizedBox(height: 8),
                          Text(
                            i18n.tr('rollout.history', {
                              'count': '${_snapshot.history.length}',
                            }),
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

  Widget _capabilityTile(SignedCapabilityId id) {
    final i18n = context.appI18n;
    final decision = _snapshot.evaluate(id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        decision.enabled ? Icons.toggle_on : Icons.toggle_off_outlined,
        color: decision.enabled ? Colors.green : Colors.orange,
        size: 30,
      ),
      title: Text(_capabilityLabel(id, i18n)),
      subtitle: Text(
        '${decision.source.name} · ${decision.reason}',
        key: ValueKey('rollout-${id.wireName}-decision'),
      ),
      trailing: Text(
        decision.enabled
            ? i18n.tr('rollout.enabled')
            : i18n.tr('rollout.disabled'),
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

String _capabilityLabel(SignedCapabilityId id, AppI18n i18n) => switch (id) {
  SignedCapabilityId.localAiReranking => i18n.tr('rollout.local_ai'),
  SignedCapabilityId.externalCatalogRefresh => i18n.tr(
    'rollout.catalog_refresh',
  ),
  SignedCapabilityId.offDeviceOperationalTelemetry => i18n.tr(
    'rollout.telemetry',
  ),
};

Color _statusColor(CapabilityRolloutSnapshot snapshot) {
  if (snapshot.hasActiveManifest) return Colors.green;
  if (snapshot.activationStatus == CapabilityActivationStatus.unconfigured) {
    return Colors.blueGrey;
  }
  return Colors.orange;
}

IconData _statusIcon(CapabilityRolloutSnapshot snapshot) {
  if (snapshot.hasActiveManifest) return Icons.verified_user_outlined;
  if (snapshot.activationStatus == CapabilityActivationStatus.unconfigured) {
    return Icons.key_off_outlined;
  }
  return Icons.shield_outlined;
}
