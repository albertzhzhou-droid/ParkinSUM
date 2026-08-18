import 'app_state.dart';

/// Minimal account state consumed by the persistent shell.
class ShellStateSlice {
  final String? userId;
  final String? userEmail;
  final bool isAuthBusy;

  const ShellStateSlice({
    required this.userId,
    required this.userEmail,
    required this.isAuthBusy,
  });

  factory ShellStateSlice.fromState(AppState state) => ShellStateSlice(
    userId: state.currentUserId,
    userEmail: state.currentUserEmail,
    isAuthBusy: state.isAuthBusy,
  );

  @override
  bool operator ==(Object other) =>
      other is ShellStateSlice &&
      other.userId == userId &&
      other.userEmail == userEmail &&
      other.isAuthBusy == isAuthBusy;

  @override
  int get hashCode => Object.hash(userId, userEmail, isAuthBusy);
}

/// Catalog-only state. Unrelated timeline, analytics, and import changes no
/// longer invalidate the full catalog page.
class CatalogStateSlice {
  final int catalogRevision;
  final Set<String> activeDrugIds;

  CatalogStateSlice({
    required this.catalogRevision,
    required Set<String> activeDrugIds,
  }) : activeDrugIds = Set<String>.unmodifiable(activeDrugIds);

  factory CatalogStateSlice.fromState(AppState state) => CatalogStateSlice(
    catalogRevision: state.catalogRevision,
    activeDrugIds: state.activeDrugIds,
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogStateSlice &&
      other.catalogRevision == catalogRevision &&
      _setEquals(other.activeDrugIds, activeDrugIds);

  @override
  int get hashCode {
    final ids = activeDrugIds.toList(growable: false)..sort();
    return Object.hash(catalogRevision, Object.hashAll(ids));
  }
}

bool _setEquals(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
