import 'package:flutter/foundation.dart';

import '../db/portable_data_restore_store.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/portable_data_restore.dart';
import '../../domain/usecases/user_portable_data_package_service.dart';

/// Prepares a same-owner, current-schema merge. It never acquires notification
/// permission or schedules a reminder; unsupported cross-store records hold.
class PortableDataRestoreCoordinator {
  const PortableDataRestoreCoordinator({
    required this.store,
    this.packageService = const UserPortableDataPackageService(),
  });
  final PortableDataRestoreStore store;
  final UserPortableDataPackageService packageService;

  Future<PortableDataRestoreRequest> prepare({
    required String packageJson,
    required String ownerScope,
    required String effectiveOwnerScope,
    required String scopeKind,
    required Iterable<FoodItem> foodCatalog,
    required Iterable<DrugDefinition> medicationCatalog,
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('portable_restore_scope_changed');
    final state = await store.loadPortableRestoreState();
    if (!authorize()) throw StateError('portable_restore_scope_changed');
    final payload = packageService.prepareLocalRestore(
      packageJson: packageJson,
      currentUserScope: effectiveOwnerScope,
      currentDoseOwnerScope: ownerScope,
      currentScopeKind: scopeKind,
      currentState: state,
      foodCatalog: foodCatalog,
      medicationCatalog: medicationCatalog,
    );
    if (!authorize()) throw StateError('portable_restore_scope_changed');
    return PortableDataRestoreRequest(
      ownerScope: ownerScope,
      sourcePackageJson: packageJson,
      packageJsonSha256: portableRestoreBytesDigest(packageJson),
      expectedStateDigest: state.digest,
      payload: payload,
    );
  }

  Future<PortableDataRestoreReceipt> commit({
    required PortableDataRestoreRequest request,
    required String currentPackageJson,
    required bool explicitlyConfirmed,
    required bool Function() authorize,
  }) async {
    if (!explicitlyConfirmed ||
        portableRestoreBytesDigest(currentPackageJson) !=
            request.packageJsonSha256 ||
        !authorize()) {
      throw StateError('portable_restore_confirmation_or_preview_changed');
    }
    // The package, owner, and before-state never enter debug output.
    debugPrint('PortableDataRestore: committing scoped merge');
    try {
      final receipt = await store.commitPortableRestore(
        request,
        authorize: authorize,
      );
      debugPrint('PortableDataRestore: scoped merge persisted');
      return receipt;
    } catch (_) {
      debugPrint('PortableDataRestore: scoped merge held');
      rethrow;
    }
  }
}
