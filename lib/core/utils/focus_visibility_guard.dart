import 'package:flutter/material.dart';

/// Keeps newly focused descendants within their nearest scrollable viewport.
///
/// This is an engineering safeguard for keyboard, switch, and voice-input
/// users. It complements, but does not replace, release-device verification
/// with the app bar, virtual keyboard, platform accessibility service, and any
/// other author-created overlays present.
class FocusVisibilityGuard extends StatefulWidget {
  final Widget child;
  final double viewportPadding;
  final Duration revealDuration;

  const FocusVisibilityGuard({
    super.key,
    required this.child,
    this.viewportPadding = 24,
    this.revealDuration = const Duration(milliseconds: 140),
  });

  @override
  State<FocusVisibilityGuard> createState() => _FocusVisibilityGuardState();
}

class _FocusVisibilityGuardState extends State<FocusVisibilityGuard>
    with WidgetsBindingObserver {
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_scheduleFocusedDescendantReveal);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleFocusedDescendantReveal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The on-screen keyboard can shrink the viewport after focus was assigned.
    _scheduleFocusedDescendantReveal();
  }

  void _scheduleFocusedDescendantReveal() {
    if (_revealScheduled || !mounted) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext == null || !_contains(focusedContext)) return;
      final renderObject = focusedContext.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      renderObject.showOnScreen(
        rect: renderObject.paintBounds.inflate(widget.viewportPadding),
        duration: widget.revealDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _contains(BuildContext candidate) {
    if (identical(candidate, context)) return true;
    if (candidate is! Element) return false;
    var contained = false;
    candidate.visitAncestorElements((ancestor) {
      if (identical(ancestor, context)) {
        contained = true;
        return false;
      }
      return true;
    });
    return contained;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
