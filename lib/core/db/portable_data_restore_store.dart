import '../models/portable_data_restore.dart';

/// Optional single-process Web capability. Other backends have no fallback to
/// sequential writes and therefore cannot accidentally advertise atomicity.
abstract interface class PortableDataRestoreStore {
  Future<PortableDataRestoreState> loadPortableRestoreState();
  Future<PortableDataRestoreReceipt?> loadPortableRestoreReceipt({
    required String ownerScope,
  });
  Future<PortableDataRestoreReceipt> commitPortableRestore(
    PortableDataRestoreRequest request, {
    required bool Function() authorize,
  });
  Future<void> rollbackPortableRestore(
    PortableDataRestoreReceipt receipt, {
    required String ownerScope,
    required bool Function() authorize,
  });
}
