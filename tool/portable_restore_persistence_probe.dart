// Synthetic engineering harness for the production Web restore capability.
// Uses real SharedPreferences, never its mock API. Serve only on a fresh,
// task-owned localhost origin. This is separate from formal-entry W31 QA.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/portable_data_restore_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

const _owner = 'mega_w08_synthetic_owner';
const _effective = 'mega_w08_opaque_synthetic_owner';
const _marker = 'mega_w08_probe_initialized';
final _at = DateTime.utc(2026, 9, 30, 4);
final _food = FoodItem(
  id: 'mega_w08_synthetic_food',
  name: 'Synthetic probe food',
  category: FoodCategory.other,
  proteinG: 0,
  carbsG: 10,
  fatG: 1,
  fiberG: 2,
  sodiumMg: 3,
  missingNutrientFields: const {'proteinG', 'energyKcal', 'waterG'},
  sourceSystem: 'SYNTHETIC_PROBE',
  sourceFoodCode: 'not_a_public_food_record',
  basisType: 'per_100g',
  preparationState: 'raw',
);
Meal _meal(String id) => Meal(
  id: id,
  eatenAt: _at,
  recordedAt: _at.add(const Duration(minutes: 5)),
  occurredAt: _at,
  timeSource: 'user_entered',
  title: 'Synthetic storage probe',
  items: [MealItem.fromFood(food: _food, quantityFactor: 1.5)],
);
String _source() => const UserPortableDataPackageService()
    .create(
      snapshot: UserPortableDataSnapshot(
        userScope: _effective,
        doseOwnerScope: _owner,
        scopeKind: 'local_device_account',
        profile: UserProfile.defaults().copyWith(patientId: _owner),
        activeDrugIds: const [],
        intakes: const [],
        meals: [_meal('mega_w08_incoming')],
        medicationCatalog: const [],
        foodCatalog: [_food],
        reminders: const [],
      ),
      generatedAt: _at.add(const Duration(hours: 1)),
    )
    .prettyJson;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(title: 'Synthetic real-storage probe', home: _Probe()),
  );
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _db = WebAppDatabase();
  bool _busy = true, _empty = false, _owned = false, _lostAck = false;
  int _mealCount = 0, _historyCount = 0;
  bool _receipt = false, _capturedUnknown = false;
  String _result = 'Loading real browser storage';
  String _digest = '';
  @override
  void initState() {
    super.initState();
    _run(_refresh, 'Read persisted state');
  }

  Future<void> _refresh() async {
    if (!kIsWeb) {
      throw StateError('web_only');
    }
    final prefs = await SharedPreferences.getInstance();
    final state = await _db.loadPortableRestoreState();
    final meals = await _db.loadMeals();
    _empty = prefs.getKeys().isEmpty;
    _owned =
        prefs.getBool(_marker) == true &&
        state.profile.patientId == _owner &&
        meals.every(
          (m) => const {'mega_w08_before', 'mega_w08_incoming'}.contains(m.id),
        ) &&
        (await _db.loadIntakes()).isEmpty;
    // No foreign owner contents or identifiers enter the page or logs.
    if (!_empty && !_owned) {
      throw StateError('non_probe_storage_refused');
    }
    _mealCount = meals.length;
    _historyCount = (await _db.loadRecoverableUserEventHistory()).length;
    _receipt = await _db.loadPortableRestoreReceipt(ownerScope: _owner) != null;
    _capturedUnknown =
        meals.isNotEmpty &&
        meals.every((m) => m.items.single.isNutrientMissing('proteinG'));
    _digest = state.digest;
  }

  Future<void> _run(Future<void> Function() action, String label) async {
    if (mounted) setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _result = '$label: PASS');
    } catch (_) {
      if (mounted) {
        setState(() => _result = '$label: HOLD (no unsupported write)');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getKeys().isNotEmpty) {
      throw StateError('fresh_origin_required');
    }
    await _db.saveUserProfile(
      UserProfile.defaults().copyWith(patientId: _owner),
    );
    final revision = RecoverableUserEventRevision.create(
      operationId: 'mega_w08_seed',
      eventType: RecoverableUserEventType.meal,
      recordId: 'mega_w08_before',
      mutationType: RecoverableUserEventMutationType.create,
      beforePayload: null,
      afterPayload: _meal('mega_w08_before').toJson(),
      recordedAtUtc: _at,
      source: 'synthetic_browser_probe',
    );
    await _db.commitRecoverableUserEventMutation(
      RecoverableUserEventMutation(revision: revision),
    );
    if (!await prefs.setBool(_marker, true)) {
      throw StateError('probe_marker_failed');
    }
    await _refresh();
    if (!_owned || _mealCount != 1 || _historyCount != 1) {
      throw StateError('seed_mismatch');
    }
  }

  Future<PortableDataRestoreRequest> _prepare() =>
      PortableDataRestoreCoordinator(store: _db).prepare(
        packageJson: _source(),
        ownerScope: _owner,
        effectiveOwnerScope: _effective,
        scopeKind: 'local_device_account',
        foodCatalog: [_food],
        medicationCatalog: const [],
        authorize: () => _owned,
      );
  Future<void> _unconfirmed() async {
    final before = (await _db.loadPortableRestoreState()).digest;
    final request = await _prepare();
    var rejected = false;
    try {
      await PortableDataRestoreCoordinator(store: _db).commit(
        request: request,
        currentPackageJson: _source(),
        explicitlyConfirmed: false,
        authorize: () => _owned,
      );
    } on StateError {
      rejected = true;
    }
    if (!rejected || before != (await _db.loadPortableRestoreState()).digest) {
      throw StateError('unconfirmed_write');
    }
    await _refresh();
  }

  Future<void> _commit() async {
    final request = await _prepare();
    final target = _lostAck
        ? WebAppDatabase(
            userStateWriter: (prefs, key, value) async {
              await prefs.setString(key, value);
              throw StateError('synthetic_lost_acknowledgement');
            },
          )
        : _db;
    final receipt = await PortableDataRestoreCoordinator(store: target).commit(
      request: request,
      currentPackageJson: _source(),
      explicitlyConfirmed: true,
      authorize: () => _owned,
    );
    await _refresh();
    if (!_receipt ||
        _mealCount != 2 ||
        _historyCount != 1 ||
        _digest != receipt.afterDigest) {
      throw StateError('committed_state_mismatch');
    }
    await _semanticCheck();
  }

  Future<void> _semanticCheck() async {
    final meals = await _db.loadMeals();
    final incoming = meals.where((m) => m.id == 'mega_w08_incoming').toList();
    if (incoming.length != 1 ||
        incoming.single.recordedAt != _at.add(const Duration(minutes: 5)) ||
        incoming.single.occurredAt != _at ||
        !incoming.single.items.single.isNutrientMissing('proteinG')) {
      throw StateError('persisted_source_semantics_mismatch');
    }
    final exported = const UserPortableDataPackageService().create(
      snapshot: UserPortableDataSnapshot(
        userScope: _effective,
        doseOwnerScope: _owner,
        scopeKind: 'local_device_account',
        profile: await _db.loadUserProfile(),
        activeDrugIds: await _db.loadActiveDrugIds(),
        intakes: await _db.loadIntakes(),
        meals: incoming,
        medicationCatalog: const [],
        foodCatalog: [_food],
        reminders: const [],
      ),
      generatedAt: _at.add(const Duration(hours: 1)),
    );
    if (portableRestoreCanonicalJson(
          (jsonDecode(exported.prettyJson) as Map)['files'],
        ) !=
        portableRestoreCanonicalJson((jsonDecode(_source()) as Map)['files'])) {
      throw StateError('eight_file_roundtrip_mismatch');
    }
    await _refresh();
  }

  Future<void> _wrongOwner() async {
    final before = (await _db.loadPortableRestoreState()).digest;
    if (await _db.loadPortableRestoreReceipt(
              ownerScope: 'other_synthetic_owner',
            ) !=
            null ||
        before != (await _db.loadPortableRestoreState()).digest) {
      throw StateError('wrong_owner_exposure');
    }
    await _refresh();
  }

  Future<void> _undo() async {
    final receipt = await _db.loadPortableRestoreReceipt(ownerScope: _owner);
    if (receipt == null) {
      throw StateError('no_current_receipt');
    }
    await _db.rollbackPortableRestore(
      receipt,
      ownerScope: _owner,
      authorize: () => _owned,
    );
    await _refresh();
    if (_mealCount != 1 ||
        _historyCount != 1 ||
        _receipt ||
        _digest != receipt.beforeDigest) {
      throw StateError('undo_mismatch');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synthetic real-storage probe')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Engineering-only synthetic data. Real browser SharedPreferences and production restore APIs. Use a fresh task-owned localhost origin. Foreign storage is refused. This harness does not replace formal-entry QA.',
          ),
          const SizedBox(height: 16),
          Text(_result, key: const Key('probe-result')),
          Text('Fresh empty origin: $_empty | Synthetic owner: $_owned'),
          Text(
            'Meals: $_mealCount | Immutable history: $_historyCount | Current receipt: $_receipt',
          ),
          Text('Captured unknown protein: $_capturedUnknown'),
          SelectableText('State digest: $_digest'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: !_busy && _empty
                ? () => _run(_seed, 'Initialize synthetic before-state')
                : null,
            child: const Text('Initialize synthetic before-state'),
          ),
          OutlinedButton(
            onPressed: !_busy && _owned && _mealCount == 1
                ? () => _run(_unconfirmed, 'Unconfirmed restore rejected')
                : null,
            child: const Text('Try unconfirmed restore'),
          ),
          CheckboxListTile(
            title: const Text(
              'Inject lost acknowledgement after actual storage write',
            ),
            value: _lostAck,
            onChanged: !_busy && _owned && _mealCount == 1
                ? (v) => setState(() => _lostAck = v!)
                : null,
          ),
          FilledButton(
            onPressed: !_busy && _owned && _mealCount == 1
                ? () => _run(
                    _commit,
                    _lostAck
                        ? 'Commit with injected lost acknowledgement'
                        : 'Commit confirmed restore',
                  )
                : null,
            child: const Text('Commit confirmed restore'),
          ),
          OutlinedButton(
            onPressed: !_busy && _owned && _mealCount == 2
                ? () => _run(_semanticCheck, 'Persisted eight-file semantics')
                : null,
            child: const Text('Verify persisted eight-file semantics'),
          ),
          OutlinedButton(
            onPressed: !_busy && _owned
                ? () => _run(_wrongOwner, 'Wrong owner receipt withheld')
                : null,
            child: const Text('Try wrong owner'),
          ),
          OutlinedButton(
            onPressed: !_busy && _owned && _receipt
                ? () => _run(_undo, 'Undo persisted receipt')
                : null,
            child: const Text('Undo persisted receipt'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Close this browser tab after commit. Reopen the same origin, verify semantics, then undo using the persisted receipt. No mock preferences or in-memory data store is used. Injected acknowledgment loss is a software fault, not a device-crash, quota, cross-tab, mobile or clinical claim.',
          ),
        ],
      ),
    ),
  );
}
