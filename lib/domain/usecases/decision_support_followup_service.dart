import '../entities/decision_support_followup.dart';

/// Pure local workflow operations. Persistence and user authentication belong
/// to the caller; this service requires that caller's owner on every operation.
final class DecisionSupportFollowupService {
  const DecisionSupportFollowupService();

  DecisionSupportFollowupLedger register({
    required DecisionSupportFollowupLedger ledger,
    required String ownerScope,
    required Iterable<DecisionSupportPrompt> prompts,
  }) {
    ledger.requireOwner(ownerScope);
    final byId = {for (final prompt in ledger.prompts) prompt.id: prompt};
    for (final prompt in prompts) {
      if (prompt.ownerScopeDigest != ledger.ownerScopeDigest) {
        throw const FormatException('Cannot register another owner\'s prompt.');
      }
      // Keep the first exact explanatory snapshot and its original timestamp.
      byId.putIfAbsent(prompt.id, () => prompt);
    }
    if (byId.length == ledger.prompts.length) return ledger;
    return DecisionSupportFollowupLedger.create(
      ownerScope: ownerScope,
      prompts: byId.values.toList(),
      feedback: ledger.feedback,
    );
  }

  DecisionSupportFollowupLedger recordFeedback({
    required DecisionSupportFollowupLedger ledger,
    required String ownerScope,
    required String promptId,
    required DecisionSupportFollowupStatus status,
    required String actorId,
    required DecisionSupportFollowupActorRole actorRole,
    required DateTime occurredAt,
    String? reason,
    DecisionSupportFeedbackReasonCategory? reasonCategory,
    DateTime? snoozedUntil,
  }) {
    ledger.requireOwner(ownerScope);
    if ((status == DecisionSupportFollowupStatus.dismissed ||
            status == DecisionSupportFollowupStatus.notApplicable ||
            status == DecisionSupportFollowupStatus.declined) &&
        reasonCategory == null) {
      throw const FormatException(
        'Closing feedback requires an owner-selected reason category.',
      );
    }
    final event = DecisionSupportFeedback.create(
      promptId: promptId,
      status: status,
      actorId: actorId,
      actorRole: actorRole,
      occurredAt: occurredAt,
      reason: reason,
      reasonCategory: reasonCategory,
      snoozedUntil: snoozedUntil,
    );
    return DecisionSupportFollowupLedger.create(
      ownerScope: ownerScope,
      prompts: ledger.prompts,
      feedback: [...ledger.feedback, event],
    );
  }

  List<DecisionSupportFollowupItem> project({
    required DecisionSupportFollowupLedger ledger,
    required String ownerScope,
    required DateTime now,
  }) {
    ledger.requireOwner(ownerScope);
    final histories = <String, List<DecisionSupportFeedback>>{};
    for (final event in ledger.feedback) {
      (histories[event.promptId] ??= []).add(event);
    }
    final items =
        ledger.prompts
            .map(
              (prompt) => DecisionSupportFollowupItem(
                prompt: prompt,
                history: histories[prompt.id] ?? const [],
                now: now,
              ),
            )
            .toList()
          ..sort((a, b) {
            final dateOrder = b.prompt.createdAt.compareTo(a.prompt.createdAt);
            return dateOrder != 0
                ? dateOrder
                : a.prompt.id.compareTo(b.prompt.id);
          });
    return List.unmodifiable(items);
  }

  /// Filters an already time-ordered local projection without changing its
  /// order. Only prompts from the current saved-meal check appear in focused
  /// workflow views; the all-records view also retains older history.
  List<DecisionSupportFollowupItem> filterForView({
    required Iterable<DecisionSupportFollowupItem> items,
    required Set<String> currentPromptIds,
    required DecisionSupportFollowupView view,
  }) {
    final result = items.where((item) {
      final isCurrent = currentPromptIds.contains(item.prompt.id);
      return switch (view) {
        DecisionSupportFollowupView.open => isCurrent && !item.isSuppressed,
        DecisionSupportFollowupView.needsReview =>
          isCurrent &&
              {
                DecisionSupportFollowupStatus.unread,
                DecisionSupportFollowupStatus.needsReview,
              }.contains(item.status),
        DecisionSupportFollowupView.snoozed => isCurrent && item.isSnoozed,
        DecisionSupportFollowupView.all => true,
      };
    });
    return List.unmodifiable(result);
  }
}
