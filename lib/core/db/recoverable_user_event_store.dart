import '../models/recoverable_user_event.dart';

/// Optional persistence capability implemented by every production app
/// database. Keeping it separate from [AppDatabase] lets older test doubles
/// remain source-compatible while production code can require this stronger
/// atomic contract.
abstract interface class RecoverableUserEventStore {
  Future<List<RecoverableUserEventRevision>> loadRecoverableUserEventHistory();

  /// Applies the event compare-and-set and appends its immutable revision in
  /// one backend transaction. Replaying the same operation is idempotent.
  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  );
}
