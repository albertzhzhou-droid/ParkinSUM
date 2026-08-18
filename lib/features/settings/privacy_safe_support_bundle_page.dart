import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/services/portable_data_export_sink.dart';
import '../../core/services/privacy_safe_support_snapshot_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/privacy_safe_support_bundle_service.dart';

abstract interface class PrivacySafeSupportClipboard {
  Future<void> writeText(String text, {required bool Function() authorize});
}

final class SystemPrivacySafeSupportClipboard
    implements PrivacySafeSupportClipboard {
  const SystemPrivacySafeSupportClipboard();

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) {
      throw StateError('Support bundle authorization expired.');
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}

final class _SupportBundleLease {
  const _SupportBundleLease({required this.userScope, required this.epoch});

  final String userScope;
  final int epoch;
}

/// User-reviewed, local-only technical support artifact.
///
/// The bundle service accepts only closed-schema technical facts. The account
/// scope here is an authorization lease and is never passed into the artifact.
class PrivacySafeSupportBundlePage extends StatefulWidget {
  const PrivacySafeSupportBundlePage({
    super.key,
    this.bundleService = const PrivacySafeSupportBundleService(),
    this.snapshotService = const PrivacySafeSupportSnapshotService(),
    this.collectSnapshot,
    this.exportSink,
    this.clipboard,
    this.now,
  });

  final PrivacySafeSupportBundleService bundleService;
  final PrivacySafeSupportSnapshotService snapshotService;
  final PrivacySafeSupportSnapshot Function()? collectSnapshot;
  final PortableDataExportSink? exportSink;
  final PrivacySafeSupportClipboard? clipboard;
  final DateTime Function()? now;

  @override
  State<PrivacySafeSupportBundlePage> createState() =>
      _PrivacySafeSupportBundlePageState();
}

class _PrivacySafeSupportBundlePageState
    extends State<PrivacySafeSupportBundlePage> {
  final Set<PrivacySafeSupportSection> _sections = {
    PrivacySafeSupportSection.build,
    PrivacySafeSupportSection.platform,
    PrivacySafeSupportSection.diagnostics,
    PrivacySafeSupportSection.governance,
  };
  PrivacySafeSupportBundleArtifact? _artifact;
  String? _artifactUserScope;
  int? _artifactEpoch;
  bool _hasObservedScope = false;
  String? _observedScope;
  int _scopeEpoch = 0;
  bool _busy = false;
  String? _errorKey;

  PortableDataExportSink get _exportSink =>
      widget.exportSink ?? const PortableDataExportSink();

  PrivacySafeSupportClipboard get _clipboard =>
      widget.clipboard ?? const SystemPrivacySafeSupportClipboard();

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentScope = context.read<AppState>().currentUserId;
    if (!_hasObservedScope) {
      _hasObservedScope = true;
      _observedScope = currentScope;
      return;
    }
    if (_observedScope != currentScope) {
      _observedScope = currentScope;
      _scopeEpoch += 1;
      _clearArtifact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n.fromLocaleTag(state.userProfile.displayLocale);
    final artifact = _artifact;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(i18n.tr('support.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _boundaryCard(context, i18n),
                    const SizedBox(height: 16),
                    _sectionCard(context, state, i18n),
                    if (_errorKey != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          i18n.tr(_errorKey!),
                          key: const ValueKey('support-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (artifact != null) ...[
                      const SizedBox(height: 16),
                      _previewCard(context, artifact, i18n),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundaryCard(BuildContext context, AppI18n i18n) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.support_agent_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                i18n.tr('support.boundary_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(i18n.tr('support.boundary_body')),
        const SizedBox(height: 8),
        Text(
          i18n.tr('support.local_only'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _sectionCard(BuildContext context, AppState state, AppI18n i18n) =>
      GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.tr('support.sections_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(i18n.tr('support.sections_body')),
            const SizedBox(height: 10),
            for (final section in PrivacySafeSupportSection.values)
              CheckboxListTile(
                key: ValueKey('support-section-${section.name}'),
                contentPadding: EdgeInsets.zero,
                value: _sections.contains(section),
                title: Text(i18n.tr('support.section_${section.name}')),
                onChanged: _busy
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected ?? false) {
                            _sections.add(section);
                          } else {
                            _sections.remove(section);
                          }
                          _clearArtifact(notify: false);
                        });
                      },
              ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: const ValueKey('support-generate'),
                onPressed:
                    _busy ||
                        _sections.isEmpty ||
                        state.currentUserId == null ||
                        state.isAuthBusy
                    ? null
                    : () => _generate(state),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(i18n.tr('support.generate')),
              ),
            ),
          ],
        ),
      );

  Widget _previewCard(
    BuildContext context,
    PrivacySafeSupportBundleArtifact artifact,
    AppI18n i18n,
  ) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          header: true,
          child: Text(
            i18n.tr('support.preview_title'),
            key: const ValueKey('support-preview-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          i18n.tr('support.preview_meta', {
            'bytes': '${artifact.byteLength}',
            'sha': artifact.artifactSha256.substring(0, 16),
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 420),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              artifact.prettyJson,
              key: const ValueKey('support-exact-preview'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('support-copy'),
              onPressed: _busy ? null : () => _copy(artifact, i18n),
              icon: const Icon(Icons.copy_outlined),
              label: Text(i18n.tr('support.copy')),
            ),
            FilledButton.icon(
              key: const ValueKey('support-save'),
              onPressed: _busy ? null : () => _save(artifact, i18n),
              icon: const Icon(Icons.download_outlined),
              label: Text(i18n.tr('support.save')),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _generate(AppState state) async {
    final lease = _captureLease(state);
    if (lease == null) {
      _setError('support.error_scope');
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      final snapshot = await Future<PrivacySafeSupportSnapshot>.sync(
        widget.collectSnapshot ?? widget.snapshotService.collect,
      );
      if (!_isLeaseCurrent(lease)) return;
      final artifact = widget.bundleService.create(
        snapshot: snapshot,
        options: PrivacySafeSupportBundleOptions(sections: _sections),
        generatedAt: _now,
      );
      if (!_isLeaseCurrent(lease)) return;
      setState(() {
        _artifact = artifact;
        _artifactUserScope = lease.userScope;
        _artifactEpoch = lease.epoch;
      });
      _log('generate', 'ready', artifact.artifactSha256);
    } catch (_) {
      _log('generate', 'failed', null);
      if (_isLeaseCurrent(lease)) _setError('support.error_generation');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(
    PrivacySafeSupportBundleArtifact artifact,
    AppI18n i18n,
  ) async {
    final lease = _artifactLease(artifact);
    if (lease == null) {
      _setError('support.error_scope');
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      if (!await _sourceStillCurrent(artifact, lease)) return;
      await _clipboard.writeText(
        artifact.prettyJson,
        authorize: () => _isArtifactCurrent(artifact, lease),
      );
      if (!mounted || !_isArtifactCurrent(artifact, lease)) return;
      _showMessage(i18n.tr('support.copied'));
      _log('copy', 'completed', artifact.artifactSha256);
    } catch (_) {
      _log('copy', 'failed', null);
      if (_isLeaseCurrent(lease)) _setError('support.error_copy');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(
    PrivacySafeSupportBundleArtifact artifact,
    AppI18n i18n,
  ) async {
    final lease = _artifactLease(artifact);
    if (lease == null) {
      _setError('support.error_scope');
      return;
    }
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      if (!await _sourceStillCurrent(artifact, lease)) return;
      final result = await _exportSink.save(
        fileName: artifact.fileName,
        contents: artifact.prettyJson,
        authorize: () => _isArtifactCurrent(artifact, lease),
      );
      if (!mounted || !_isArtifactCurrent(artifact, lease)) return;
      if (result.delivery == 'unsupported') {
        await _clipboard.writeText(
          artifact.prettyJson,
          authorize: () => _isArtifactCurrent(artifact, lease),
        );
        if (!mounted || !_isArtifactCurrent(artifact, lease)) return;
        _showMessage(i18n.tr('support.save_fallback_copied'));
        _log('save', 'fallback_copy', artifact.artifactSha256);
        return;
      }
      final key = result.delivery == 'browser_download'
          ? 'support.download_requested'
          : 'support.existing_verified';
      _showMessage(i18n.tr(key));
      _log('save', result.delivery, artifact.artifactSha256);
    } catch (_) {
      _log('save', 'failed', null);
      if (_isLeaseCurrent(lease)) _setError('support.error_save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _sourceStillCurrent(
    PrivacySafeSupportBundleArtifact artifact,
    _SupportBundleLease lease,
  ) async {
    final snapshot = await Future<PrivacySafeSupportSnapshot>.sync(
      widget.collectSnapshot ?? widget.snapshotService.collect,
    );
    if (!_isArtifactCurrent(artifact, lease)) return false;
    if (snapshot.revisionSha256 != artifact.sourceRevisionSha256) {
      _clearArtifact();
      _setError('support.error_source_changed');
      _log('revalidate', 'source_changed', null);
      return false;
    }
    return true;
  }

  _SupportBundleLease? _captureLease(AppState state) {
    final scope = state.currentUserId?.trim();
    if (scope == null || scope.isEmpty || state.isAuthBusy) return null;
    return _SupportBundleLease(userScope: scope, epoch: _scopeEpoch);
  }

  _SupportBundleLease? _artifactLease(
    PrivacySafeSupportBundleArtifact artifact,
  ) {
    if (!identical(_artifact, artifact) ||
        _artifactUserScope == null ||
        _artifactEpoch == null) {
      return null;
    }
    return _SupportBundleLease(
      userScope: _artifactUserScope!,
      epoch: _artifactEpoch!,
    );
  }

  bool _isLeaseCurrent(_SupportBundleLease lease) {
    if (!mounted || lease.epoch != _scopeEpoch) return false;
    final state = context.read<AppState>();
    return !state.isAuthBusy && state.currentUserId == lease.userScope;
  }

  bool _isArtifactCurrent(
    PrivacySafeSupportBundleArtifact artifact,
    _SupportBundleLease lease,
  ) => identical(_artifact, artifact) && _isLeaseCurrent(lease);

  void _clearArtifact({bool notify = true}) {
    void clear() {
      _artifact = null;
      _artifactUserScope = null;
      _artifactEpoch = null;
      _errorKey = null;
    }

    if (notify && mounted) {
      setState(clear);
    } else {
      clear();
    }
  }

  void _setError(String key) {
    if (!mounted) return;
    setState(() => _errorKey = key);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _log(String operation, String outcome, String? digest) {
    if (!kDebugMode) return;
    final digestPrefix = digest == null ? 'none' : digest.substring(0, 12);
    debugPrint(
      '[support_bundle] operation=$operation outcome=$outcome '
      'digest_prefix=$digestPrefix',
    );
  }
}
