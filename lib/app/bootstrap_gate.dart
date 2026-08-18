import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/liquid_glass_theme.dart';
import 'bootstrap_attempt_controller.dart';

class BootstrapGate extends StatefulWidget {
  static const loadingKey = ValueKey<String>('bootstrap-loading');
  static const failureKey = ValueKey<String>('bootstrap-failure');
  static const retryButtonKey = ValueKey<String>('bootstrap-retry');

  const BootstrapGate({
    super.key,
    required this.controller,
    required this.loadingLabel,
    required this.failureLabel,
    required this.retryLabel,
    required this.successBuilder,
  });

  final BootstrapAttemptController controller;
  final String loadingLabel;
  final String failureLabel;
  final String retryLabel;
  final WidgetBuilder successBuilder;

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  @override
  void initState() {
    super.initState();
    _scheduleAttempt();
  }

  @override
  void didUpdateWidget(covariant BootstrapGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _scheduleAttempt();
    }
  }

  void _scheduleAttempt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runAttempt());
    });
  }

  Future<void> _runAttempt() async {
    final attempt = widget.controller.run();
    if (mounted) {
      setState(() {});
    }
    await attempt;
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.controller.phase) {
      BootstrapAttemptPhase.succeeded => widget.successBuilder(context),
      BootstrapAttemptPhase.failed => _failure(context),
      BootstrapAttemptPhase.idle || BootstrapAttemptPhase.running => _loading(),
    };
  }

  Widget _loading() {
    return Scaffold(
      key: BootstrapGate.loadingKey,
      backgroundColor: Colors.transparent,
      body: Center(
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.6),
              const SizedBox(height: 14),
              Text(
                widget.loadingLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LiquidGlass.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _failure(BuildContext context) {
    return Scaffold(
      key: BootstrapGate.failureKey,
      backgroundColor: Colors.transparent,
      body: Center(
        child: Semantics(
          liveRegion: true,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.failureLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LiquidGlass.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: BootstrapGate.retryButtonKey,
                  onPressed: widget.controller.isRunning ? null : _runAttempt,
                  icon: const Icon(Icons.refresh),
                  label: Text(widget.retryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
