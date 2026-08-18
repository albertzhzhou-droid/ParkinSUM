import '../models/atomic_onboarding_commit.dart';
import '../models/intake.dart';
import '../models/user_profile.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/app_repository.dart';

/// Serializes first-day commits and delegates the atomicity guarantee to the
/// repository backend. Failed operations do not poison later retries.
class AtomicOnboardingCommitCoordinator {
  AtomicOnboardingCommitCoordinator({required AppRepository repository})
    : _repository = repository;

  final AppRepository _repository;
  Future<void> _tail = Future<void>.value();

  Future<AtomicOnboardingCommit> commit({
    required UserProfile profile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) {
    final request = AtomicOnboardingCommit.create(
      profile: profile,
      activeDrugIds: activeDrugIds,
      intakes: intakes,
    );
    final operation = _tail.then((_) async {
      debugPrint(
        '[OnboardingCommit] start operation=${_shortId(request.operationId)}',
      );
      try {
        await _repository.commitOnboarding(request);
        debugPrint(
          '[OnboardingCommit] committed '
          'operation=${_shortId(request.operationId)}',
        );
        return request;
      } catch (_) {
        debugPrint(
          '[OnboardingCommit] failed operation=${_shortId(request.operationId)}',
        );
        rethrow;
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  String _shortId(String operationId) =>
      operationId.substring(operationId.length - 12);
}
