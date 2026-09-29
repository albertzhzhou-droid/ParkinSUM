import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/services/firebase_backend.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/operational_observability.dart';

class OperationalObservabilityPage extends StatefulWidget {
  const OperationalObservabilityPage({super.key, this.ledger, this.now});

  final OperationalObservabilityLedger? ledger;
  final DateTime Function()? now;

  @override
  State<OperationalObservabilityPage> createState() =>
      _OperationalObservabilityPageState();
}

class _OperationalObservabilityPageState
    extends State<OperationalObservabilityPage> {
  OperationalObservabilityLedger get _ledger =>
      widget.ledger ?? OperationalObservabilityLedger.instance;

  DateTime get _now => (widget.now?.call() ?? DateTime.now()).toUtc();

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final snapshot = _ledger.snapshot(now: _now);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(title: Text(i18n.tr('operations.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.shield_outlined),
                            title: Text(i18n.tr('operations.local_title')),
                            subtitle: Text(
                              i18n.tr('operations.local_boundary'),
                            ),
                          ),
                          SwitchListTile(
                            key: const ValueKey(
                              'operational-observability-local-toggle',
                            ),
                            contentPadding: EdgeInsets.zero,
                            value: snapshot.collectionEnabled,
                            title: Text(i18n.tr('operations.local_collection')),
                            subtitle: Text(
                              i18n.tr('operations.local_collection_help'),
                            ),
                            onChanged: (enabled) {
                              setState(
                                () => _ledger.setCollectionEnabled(enabled),
                              );
                            },
                          ),
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cloud_off_outlined),
                            title: Text(i18n.tr('operations.export_title')),
                            subtitle: Text(
                              i18n.tr('operations.export_disabled'),
                            ),
                            trailing: const Chip(
                              key: ValueKey(
                                'operational-observability-export-disabled',
                              ),
                              label: Text('OFF'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.tr('operations.allowed_title'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final category
                              in OperationalObservabilityNotice
                                  .allowedCategories)
                            Text('• $category'),
                          const SizedBox(height: 14),
                          Text(
                            i18n.tr('operations.excluded_title'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final exclusion
                              in OperationalObservabilityNotice.exclusions)
                            Text('• $exclusion'),
                          const SizedBox(height: 12),
                          SelectableText(
                            i18n.tr('operations.notice_identity', {
                              'version':
                                  '$operationalObservabilityNoticeVersion',
                              'digest': OperationalObservabilityNotice
                                  .sha256Digest
                                  .substring(0, 16),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  i18n.tr('operations.snapshot_title'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                key: const ValueKey(
                                  'operational-observability-refresh',
                                ),
                                tooltip: i18n.tr('operations.refresh'),
                                onPressed: () => setState(() {}),
                                icon: const Icon(Icons.refresh_outlined),
                              ),
                            ],
                          ),
                          Text(
                            i18n.tr('operations.snapshot_summary', {
                              'count': '${snapshot.totalCount}',
                              'window': '${snapshot.windowMinutes}',
                            }),
                          ),
                          if (snapshot.overflowed) ...[
                            const SizedBox(height: 8),
                            Text(
                              i18n.tr('operations.snapshot_overflow', {
                                'count': '${snapshot.droppedObservationCount}',
                              }),
                              key: const ValueKey(
                                'operational-observability-overflow',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (snapshot.aggregates.isEmpty)
                            Text(i18n.tr('operations.snapshot_empty'))
                          else
                            for (final aggregate in snapshot.aggregates)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${aggregate.category.name} · '
                                  '${aggregate.outcome.name}',
                                ),
                                subtitle: Text(
                                  '${aggregate.duration.name} · '
                                  '${aggregate.capability.name}',
                                ),
                                trailing: Text('${aggregate.count}'),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      child: Text(
                        i18n.tr('operations.release_boundary', {
                          'platform': _platformFamily(),
                          'backend': FirebaseBackend.backendMode,
                          'source': AlgorithmConfigurationIdentity
                              .registeredAlgorithmSourceBundleSha256
                              .substring(0, 12),
                        }),
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

  String _platformFamily() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
