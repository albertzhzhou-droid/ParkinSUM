import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../domain/usecases/pinned_timezone_rules.dart';

final pinnedTimezoneRulesService = PinnedTimezoneRulesService();

/// Loads the bundled source once; concurrent initialization shares one future.
/// Failure is explicit and never falls back to a differently labeled database.
final class PinnedTimezoneRulesService {
  PinnedTimezoneRulesService({Future<List<int>> Function()? loadBytes})
    : _loadBytes = loadBytes ?? _loadAsset;

  final Future<List<int>> Function() _loadBytes;
  Future<PinnedTimezoneRules>? _loading;
  PinnedTimezoneRules? _loaded;

  PinnedTimezoneRules? get loaded => _loaded;

  Future<PinnedTimezoneRules> load() {
    final cached = _loaded;
    if (cached != null) return Future<PinnedTimezoneRules>.value(cached);
    final active = _loading;
    if (active != null) return active;
    late final Future<PinnedTimezoneRules> operation;
    operation = _performLoad().whenComplete(() {
      if (identical(_loading, operation)) _loading = null;
    });
    _loading = operation;
    return operation;
  }

  Future<PinnedTimezoneRules> _performLoad() async {
    final rules = PinnedTimezoneRules.fromBytes(await _loadBytes());
    _loaded = rules;
    debugPrint('[timezone] Offline rules verified: $pinnedTimezoneRelease.');
    return rules;
  }

  Future<void> initializeForApp() async {
    final rules = await load();
    rules.initializeGlobalDatabase();
  }

  static Future<List<int>> _loadAsset() async {
    final bytes = await rootBundle.load(pinnedTimezoneAssetPath);
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }
}
