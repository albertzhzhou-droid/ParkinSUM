typedef BootstrapOperation = Future<void> Function();

enum BootstrapAttemptPhase { idle, running, failed, succeeded }

/// Owns the app bootstrap lifecycle without retaining exception details.
///
/// Calls made while an attempt is running share the same future. A failed
/// attempt may be retried, while a completed attempt is not run again.
class BootstrapAttemptController {
  BootstrapAttemptController({required BootstrapOperation bootstrap})
    : _bootstrap = bootstrap;

  final BootstrapOperation _bootstrap;

  BootstrapAttemptPhase _phase = BootstrapAttemptPhase.idle;
  Future<BootstrapAttemptPhase>? _inFlight;

  BootstrapAttemptPhase get phase => _phase;
  bool get isRunning => _inFlight != null;

  Future<BootstrapAttemptPhase> run() {
    final activeAttempt = _inFlight;
    if (activeAttempt != null) return activeAttempt;
    if (_phase == BootstrapAttemptPhase.succeeded) {
      return Future<BootstrapAttemptPhase>.value(_phase);
    }

    _phase = BootstrapAttemptPhase.running;
    late final Future<BootstrapAttemptPhase> attempt;
    attempt =
        Future<BootstrapAttemptPhase>.sync(() async {
          try {
            await _bootstrap();
            _phase = BootstrapAttemptPhase.succeeded;
          } catch (_) {
            _phase = BootstrapAttemptPhase.failed;
          }
          return _phase;
        }).whenComplete(() {
          if (identical(_inFlight, attempt)) {
            _inFlight = null;
          }
        });
    _inFlight = attempt;
    return attempt;
  }
}
