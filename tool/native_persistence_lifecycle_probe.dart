// Engineering-only native probe. The host must first verify a task-owned,
// empty simulator and the isolated Android attestation package. This target
// uses the production service graph; it is not formal-entry UI verification.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/services/firebase_backend.dart';
import 'package:parkinsum_companion/core/services/pinned_timezone_rules_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';

const _isolation = String.fromEnvironment(
  'PARKINSUM_NATIVE_SYNTHETIC_ISOLATION',
);
const _runId = String.fromEnvironment('PARKINSUM_NATIVE_PROBE_RUN_ID');
const _markerKey = 'parkinsum_native_synthetic_persistence_probe_v1';
const _recordId = 'mega_native_synthetic_meal';
const _protocol = 'owned-native-persistence-observation-v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb ||
      !{
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform) ||
      _isolation != 'owned-empty-emulator-v1' ||
      !RegExp(r'^mega-native-[a-z0-9-]{8,64}$').hasMatch(_runId) ||
      FirebaseBackend.enabled) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Synthetic isolation HOLD'))),
      ),
    );
    return;
  }
  await pinnedTimezoneRulesService.initializeForApp();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with WidgetsBindingObserver {
  AppState? _state;
  SharedPreferences? _prefs;
  bool _busy = false;
  String _result = 'Loading native production services';
  int _resumes = 0;
  Map<String, Object?> _report = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run(initial: true);
  }

  Map<String, Object?> _snapshot(AppState state) => {
    'owner': state.userProfile.patientId,
    'onboarded': state.isOnboarded,
    'profile': state.userProfile.toJson(),
    'active_drug_ids': state.activeDrugIds.toList()..sort(),
    'meals': state.meals.map((meal) => meal.toJson()).toList(),
    'intakes': state.intakes.map((intake) => intake.toJson()).toList(),
    'history': state.recoverableEventHistory
        .map((revision) => revision.toJson())
        .toList(),
  };

  String _canonical(Object? value) => portableRestoreCanonicalJson(value);
  String _digest(Object? value) =>
      sha256.convert(utf8.encode(_canonical(value))).toString();

  Future<void> _run({bool initial = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      await prefs.reload();
      final markerBefore = prefs.getString(_markerKey);
      if (markerBefore != null) {
        final marker = jsonDecode(markerBefore) as Map<String, dynamic>;
        if (marker['protocol'] != _protocol || marker['run_id'] != _runId) {
          throw StateError('foreign_probe_marker_refused');
        }
      }
      if (_state == null) {
        final services = Services.createDefault();
        if (services.isEphemeral ||
            services.appDatabase is! NativeAppDatabase) {
          throw StateError('native_production_backend_required');
        }
        _state = AppState(services: services);
      }
      final state = _state!;
      await state.bootstrap();
      if (markerBefore == null) {
        if (!initial ||
            state.isOnboarded ||
            state.meals.isNotEmpty ||
            state.intakes.isNotEmpty ||
            state.recoverableEventHistory.isNotEmpty) {
          throw StateError('nonempty_user_storage_refused');
        }
        await state.completeOnboarding(
          profile: state.userProfile.copyWith(displayLocale: 'en'),
          activeDrugIds: const [],
        );
        final food = FoodItem(
          id: 'mega_native_synthetic_food',
          name: 'Synthetic native probe food',
          category: FoodCategory.other,
          proteinG: 0,
          carbsG: 10,
          fatG: 1,
          fiberG: 2,
          sodiumMg: 3,
          missingNutrientFields: const {'proteinG', 'energyKcal', 'waterG'},
          sourceSystem: 'SYNTHETIC_PROBE',
          basisType: 'per_100g',
        );
        // A fixed local civil value matches the existing native database's
        // local-DateTime representation. UTC/civil migration is not asserted.
        final at = DateTime(2026, 9, 30, 4);
        final meal = Meal(
          id: _recordId,
          eatenAt: at,
          recordedAt: at.add(const Duration(minutes: 5)),
          occurredAt: at,
          timeSource: 'user_entered',
          title: 'Synthetic native before edit',
          items: [MealItem.fromFood(food: food, quantityFactor: 1.5)],
        );
        await state.addMeal(meal);
        await state.updateMeal(
          meal.copyWith(
            title: 'Synthetic native after edit',
            items: [meal.items.single.copyWith(quantityFactor: 1.75)],
          ),
        );
        if (state.meals.length != 1 ||
            state.meals.single.id != _recordId ||
            state.meals.single.title != 'Synthetic native after edit' ||
            state.meals.single.items.single.quantityFactor != 1.75 ||
            !state.meals.single.items.single.isNutrientMissing('proteinG') ||
            state.recoverableEventHistory.length != 2 ||
            state.intakes.isNotEmpty ||
            state.activeDrugIds.isNotEmpty) {
          throw StateError('seed_or_edit_not_durably_accepted');
        }
        final snapshot = _snapshot(state);
        if (!await prefs.setString(
          _markerKey,
          jsonEncode({
            'protocol': _protocol,
            'run_id': _runId,
            'snapshot': snapshot,
            'snapshot_sha256': _digest(snapshot),
          }),
        )) {
          throw StateError('durable_probe_marker_failed');
        }
        // Re-read through the production graph before the host terminates the
        // OS process. A later run must independently observe the same marker.
        await state.bootstrap();
      }
      await prefs.reload();
      final marker = jsonDecode(prefs.getString(_markerKey)!) as Map;
      final snapshot = _snapshot(state);
      final exact = _canonical(snapshot) == _canonical(marker['snapshot']);
      final digest = _digest(snapshot);
      if (!exact || digest != marker['snapshot_sha256']) {
        throw StateError('whole_persisted_snapshot_changed');
      }
      _report = {
        'protocol': _protocol,
        'run_id': _runId,
        'platform': defaultTargetPlatform.name,
        'storage_boundary': 'production_native_sqlite_and_shared_preferences',
        'target': 'tool/native_persistence_lifecycle_probe.dart',
        'formal_entry_verified': false,
        'real_user_data_accessed': false,
        'marker_present_at_process_entry': markerBefore != null,
        'whole_snapshot_exact': exact,
        'snapshot_sha256': digest,
        'meals': state.meals.length,
        'intakes': state.intakes.length,
        'history': state.recoverableEventHistory.length,
        'observed_resume_callbacks': _resumes,
        'device_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        'visible_notification_delivery_verified': false,
      };
      _result = 'Whole native snapshot: PASS';
      debugPrint(
        'PARKINSUM_NATIVE_PERSISTENCE_OBSERVATION:${jsonEncode(_report)}',
      );
    } catch (_) {
      _result = 'Native persistence: HOLD';
      debugPrint('[NativeSyntheticProbe] persistence:held');
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _resumes++;
      _run();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synthetic native persistence probe')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Engineering verification on an owned empty simulator. Real native '
            'services, SQLite and preferences. This target is separate from '
            'the formal application entry and never claims real-device delivery.',
          ),
          const SizedBox(height: 16),
          Text(_result),
          SelectableText(const JsonEncoder.withIndent('  ').convert(_report)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(),
            child: const Text('Read whole persisted snapshot again'),
          ),
        ],
      ),
    ),
  );
}
