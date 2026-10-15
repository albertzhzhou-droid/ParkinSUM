import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/app_database_web.dart';
import '../core/models/portable_data_restore.dart';
import '../core/models/user_profile.dart';
import '../core/services/personal_log_handoff_document_service.dart';
import '../core/services/portable_data_restore_coordinator.dart';
import '../core/services/services.dart';
import '../core/state/app_state.dart';
import '../domain/usecases/personal_log_handoff_summary_service.dart';
import '../domain/usecases/user_portable_data_package_service.dart';
import 'personal_log_view_benchmark_fixture.dart';

typedef PersistentPhaseMeasure =
    Future<Map<String, Object>> Function(
      String phase,
      Future<int> Function() operation,
    );

/// Separately invoked release-Web experiment. Only an empty origin, or a
/// marker-owned empty origin from this exact source, may become a fixture store.
/// It measures real service/storage paths, not a browser or OS process restart.
final class PersonalLogPersistentBenchmark {
  PersonalLogPersistentBenchmark._(
    this.services,
    this.preferences,
    this.source,
  );

  static const markerKey = 'parkinsum.synthetic_persistent_benchmark.v1';
  static const markerFormat = 'parkinsum.synthetic-persistent-benchmark/1';
  final Services services;
  final SharedPreferences preferences;
  final String source;
  int _nonce = 0;
  String get _expectedMarker =>
      jsonEncode({'format': markerFormat, 'source': source});
  bool get _authorized =>
      services.authService.currentUserId == 'local_user' &&
      preferences.getString(markerKey) == _expectedMarker;

  static Future<PersonalLogPersistentBenchmark> open({
    required String source,
  }) async {
    if (!kIsWeb ||
        !kReleaseMode ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(source)) {
      throw StateError('persistent_benchmark_requires_release_web_and_source');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final marker = preferences.getString(markerKey);
    final expected = jsonEncode({'format': markerFormat, 'source': source});
    requireDisposableBenchmarkOrigin(
      existingKeys: preferences.getKeys(),
      marker: marker,
      expectedMarker: expected,
    );
    final services = Services.createDefault();
    await services.ready;
    if (services.isEphemeral || services.appDatabase is! WebAppDatabase) {
      throw StateError('persistent_benchmark_requires_actual_local_web_store');
    }
    final owner = await services.authService.ensureUser();
    if (owner != 'local_user') {
      throw StateError('persistent_benchmark_requires_disposable_local_owner');
    }
    await preferences.reload();
    final session = PersonalLogPersistentBenchmark._(
      services,
      preferences,
      source,
    );
    await session._requireEmpty();
    await session._requireNoCareOrDraft();
    if (marker == null) {
      if (await services.userDataService.loadOnboarded() ||
          jsonEncode(
                (await services.userDataService.loadUserProfile()).toJson(),
              ) !=
              jsonEncode(UserProfile.defaults().toJson())) {
        throw StateError('persistent_benchmark_nondefault_profile');
      }
      if (!await preferences.setString(markerKey, expected)) {
        throw StateError('persistent_benchmark_marker_not_persisted');
      }
    }
    return session;
  }

  WebAppDatabase get store => services.appDatabase as WebAppDatabase;
  Future<void> _requireNoCareOrDraft() async {
    final care = await services.careWorkspaceService.load('local_user');
    if (care.observations.isNotEmpty ||
        care.notes.isNotEmpty ||
        care.followups.prompts.isNotEmpty ||
        care.followups.feedback.isNotEmpty ||
        care.medicationDiscussionEntries.isNotEmpty ||
        care.medicationDiscussionOutcomes.isNotEmpty ||
        care.medicationListReviews.isNotEmpty ||
        await services.mealDraftService.load('local_user') != null) {
      throw StateError('persistent_benchmark_existing_care_or_draft');
    }
  }

  Future<void> _requireEmpty() async {
    if (services.authService.currentUserId != 'local_user') {
      throw StateError('persistent_benchmark_owner_changed');
    }
    final state = await store.loadPortableRestoreState();
    if (state.recordIds.values.any((ids) => ids.isNotEmpty) ||
        (await services.userDataService.loadRecoverableUserEventHistory())
            .isNotEmpty ||
        await services.userDataService.loadOnboarded() ||
        portableRestoreCanonicalJson(state.profile.toJson()) !=
            portableRestoreCanonicalJson(UserProfile.defaults().toJson())) {
      throw StateError('persistent_benchmark_existing_records');
    }
  }

  Future<void> _requireFixture(PersonalLogBenchmarkFixture fixture) async {
    final meals = await services.userDataService.loadMeals();
    final intakes = await services.userDataService.loadIntakes();
    if (!benchmarkRecordsMatchById(
          meals.map((v) => v.toJson()),
          fixture.meals.map((v) => v.toJson()),
        ) ||
        !benchmarkRecordsMatchById(
          intakes.map((v) => v.toJson()),
          fixture.intakes.map((v) => v.toJson()),
        ) ||
        (await services.userDataService.loadActiveDrugIds()).isNotEmpty) {
      throw StateError('persistent_benchmark_fixture_changed');
    }
  }

  /// A failed phase keeps its failure and partial raw samples in the caller's
  /// console protocol. No missing measurement is replaced by a zero duration.
  Future<Map<String, Object?>> measure({
    required PersonalLogBenchmarkFixture fixture,
    required BuildContext context,
    required PersistentPhaseMeasure measurePhase,
    required void Function(Map<String, Object?> evidence) retainEvidence,
  }) async {
    await preferences.reload();
    if (!_authorized) throw StateError('persistent_benchmark_lease_changed');
    await _requireEmpty();
    await _requireNoCareOrDraft();
    final before = await store.loadPortableRestoreState();
    final originalProfile = await services.userDataService.loadUserProfile();
    final seededProfile = originalProfile.copyWith(
      timezone: 'Etc/UTC',
      displayLocale: 'en-US',
    );
    final phases = <String, Object>{};
    final holds = <Map<String, Object?>>[];
    final nonces = <Map<String, Object?>>[];
    final report = <String, Object?>{
      'fixtureInputSha256': fixture.inputSha256,
      'fixture': fixture.parameters,
      'persistentFixtureSeededAndReadBack': false,
      'backend': 'Services.createDefault / WebAppDatabase / SharedPreferences',
      'storageIsolationScope':
          'One initially empty marker-owned origin and one visible tab; no cross-tab lock guarantee.',
      'startupScope':
          'New service graph and AppState over durable records, not browser/OS restart or cold HTTP fetch.',
      'unknownSyntheticMedicationReferenceCount': fixture.intakes.length,
      'clinicalInterpretation': 'None; software counts and durations only.',
      'catalogueScope':
          'Shipped catalogue; six fixed queries and warm index. Personal record count is not catalogue size.',
      'reportScope':
          'Complete-input countsOnly summary/HTML with production budgets; raster PDF uses first 20 meals/4 intakes.',
      'restoreTimingScope':
          'Package generation, prepare, confirmed commit, readback and rollback attempts; fixed operation nonce, unchanged event values.',
      'phases': phases,
      'holds': holds,
      'restoreOperationNonces': nonces,
      'cleanup': 'not_yet_verified',
    };
    // Retain by reference before writes. A cleanup refusal must not erase
    // previously completed measurements from the caller's final report.
    retainEvidence(report);
    Future<void> phase(String name, Future<int> Function() operation) async {
      try {
        phases[name] = await measurePhase(name, operation);
      } catch (error) {
        if (error is PersonalLogBenchmarkIncomplete) {
          phases[name] = error.evidence;
        }
        holds.add({
          'phase': name,
          'status': 'failed_or_held',
          'reason': '$error',
        });
      }
    }

    // Seeding is outside measured startup intervals. It deliberately retains
    // the original invalid/missing fixture fields rather than making a valid
    // export dataset to obtain an artificial restoration pass.
    try {
      await services.userDataService.saveUserProfile(seededProfile);
      if (!_authorized) throw StateError('persistent_benchmark_lease_changed');
      await services.userDataService.saveMeals(fixture.meals);
      if (!_authorized) throw StateError('persistent_benchmark_lease_changed');
      await services.userDataService.saveIntakes(fixture.intakes);
      await preferences.reload();
      if (!_authorized) {
        throw StateError('persistent_benchmark_lease_changed');
      }
      final current = await store.loadPortableRestoreState();
      final currentOther = current.json
        ..remove('profile')
        ..remove('meals')
        ..remove('intakes');
      final beforeOther = before.json
        ..remove('profile')
        ..remove('meals')
        ..remove('intakes');
      final profileJson = portableRestoreCanonicalJson(
        current.profile.toJson(),
      );
      if (portableRestoreCanonicalJson(currentOther) !=
              portableRestoreCanonicalJson(beforeOther) ||
          (profileJson !=
                  portableRestoreCanonicalJson(originalProfile.toJson()) &&
              profileJson !=
                  portableRestoreCanonicalJson(seededProfile.toJson()))) {
        throw StateError('persistent_benchmark_foreign_state_cleanup_refused');
      }
      await _requireFixture(fixture);
      report['persistentFixtureSeededAndReadBack'] = true;
      await phase(
        'persistent_fresh_services_and_app_state_bootstrap',
        () async {
          final freshServices = Services.createDefault();
          final state = AppState(services: freshServices);
          try {
            await freshServices.ready;
            await state.bootstrap();
            if (freshServices.isEphemeral ||
                freshServices.appDatabase is! WebAppDatabase ||
                state.meals.length != fixture.meals.length ||
                state.intakes.length != fixture.intakes.length) {
              throw StateError(
                'persistent_benchmark_bootstrap_count_or_backend',
              );
            }
            return state.meals.length + state.intakes.length;
          } finally {
            state.dispose();
          }
        },
      );

      // Production catalogue searches over the actual shipped catalogue,
      // declared independently of the number of personal records.
      await phase('catalogue_search_warm_index_fixed_queries', () async {
        var consumed = 0;
        for (final query in [
          'oat',
          'rice',
          'USDA',
          'Sinemet',
          'levodopa',
          'oral',
        ]) {
          consumed += services.catalogEngine.searchFoods(query).length;
          consumed += services.catalogEngine.searchDrugs(query).length;
        }
        return consumed;
      });

      final snapshot = PersonalLogHandoffSnapshot(
        ownerScope: 'local_user',
        profile: originalProfile.copyWith(timezone: 'Etc/UTC'),
        activeDrugIds: const [],
        meals: fixture.meals,
        intakes: fixture.intakes,
        foodCatalog: fixture.foods,
        medicationCatalog: fixture.drugs,
      );
      final options = PersonalLogHandoffOptions(
        startDate: DateTime.utc(2026, 9, 1),
        endDateInclusive: DateTime.utc(2026, 9, 30),
        sections: PersonalLogHandoffSection.values.toSet(),
        redaction: PersonalLogHandoffRedaction.countsOnly,
      );
      await phase('handoff_all_input_counts_only_summary_and_html', () async {
        final artifact = const PersonalLogHandoffSummaryService().create(
          snapshot: snapshot,
          options: options,
          generatedAt: PersonalLogBenchmarkFixture.asOf,
        );
        final html = const PersonalLogHandoffHtmlSerializer().render(artifact);
        return html.length + artifact.pages.length;
      });

      // PDF uses a fixed bounded subset while the summary/HTML phase above
      // attempts the complete input and retains any declared budget HOLD.
      final bounded = PersonalLogHandoffSnapshot(
        ownerScope: snapshot.ownerScope,
        profile: snapshot.profile,
        activeDrugIds: const [],
        meals: fixture.meals.take(20),
        intakes: fixture.intakes.take(4),
        foodCatalog: fixture.foods,
        medicationCatalog: fixture.drugs,
      );
      final boundedOptions = PersonalLogHandoffOptions(
        startDate: options.startDate,
        endDateInclusive: options.endDateInclusive,
        sections: options.sections,
        redaction: PersonalLogHandoffRedaction.standard,
      );
      await phase('handoff_fixed_20_meals_4_intakes_raster_pdf', () async {
        final artifact = const PersonalLogHandoffSummaryService().create(
          snapshot: bounded,
          options: boundedOptions,
          generatedAt: PersonalLogBenchmarkFixture.asOf,
        );
        final bytes = await const SystemPersonalLogHandoffPdfRenderer().render(
          context: context,
          artifact: artifact,
        );
        return bytes.length;
      });
    } catch (error) {
      holds.add({
        'phase': 'persistent_fixture_seed',
        'status': 'failed_or_held',
        'reason': '$error',
      });
    } finally {
      // Reload after storage failure before trusting the preference cache.
      await preferences.reload();
      if (!_authorized) {
        throw StateError('persistent_benchmark_cleanup_lease_changed');
      }
      final current = await store.loadPortableRestoreState();
      final currentOther = current.json
        ..remove('profile')
        ..remove('meals')
        ..remove('intakes');
      final beforeOther = before.json
        ..remove('profile')
        ..remove('meals')
        ..remove('intakes');
      final profileJson = portableRestoreCanonicalJson(
        current.profile.toJson(),
      );
      if (portableRestoreCanonicalJson(currentOther) !=
              portableRestoreCanonicalJson(beforeOther) ||
          (profileJson !=
                  portableRestoreCanonicalJson(originalProfile.toJson()) &&
              profileJson !=
                  portableRestoreCanonicalJson(seededProfile.toJson()))) {
        throw StateError('persistent_benchmark_foreign_state_cleanup_refused');
      }
      final meals = await services.userDataService.loadMeals();
      final intakes = await services.userDataService.loadIntakes();
      final ownMeals = fixture.meals.map((v) => jsonEncode(v.toJson())).toSet();
      final ownIntakes = fixture.intakes
          .map((v) => jsonEncode(v.toJson()))
          .toSet();
      if (meals.any((v) => !ownMeals.contains(jsonEncode(v.toJson()))) ||
          intakes.any((v) => !ownIntakes.contains(jsonEncode(v.toJson())))) {
        throw StateError('persistent_benchmark_foreign_rows_cleanup_refused');
      }
      await services.userDataService.saveMeals([]);
      await services.userDataService.saveIntakes([]);
      await services.userDataService.saveUserProfile(originalProfile);
      await preferences.reload();
      await _requireEmpty();
      await _requireNoCareOrDraft();
      if ((await store.loadPortableRestoreState()).digest != before.digest) {
        throw StateError('persistent_benchmark_cleanup_readback_mismatch');
      }
      report['cleanup'] =
          'owned_fixture_rows_removed_and_original_empty_state_read_back';
    }

    final packageService = const UserPortableDataPackageService();
    final coordinator = PortableDataRestoreCoordinator(store: store);
    await phase('portable_package_prepare_commit_readback', () async {
      if (!_authorized) throw StateError('persistent_benchmark_lease_changed');
      await _requireEmpty();
      final artifact = packageService.create(
        snapshot: UserPortableDataSnapshot(
          userScope: 'local_user',
          doseOwnerScope: 'local_user',
          scopeKind: 'local_device_account',
          profile: originalProfile,
          activeDrugIds: const [],
          intakes: fixture.intakes,
          meals: fixture.meals,
          medicationCatalog: fixture.drugs,
          foodCatalog: fixture.foods,
          reminders: const [],
        ),
        // Only the fixed operation nonce changes across repetitions. Actual
        // meal/intake timestamps, values and identifiers never change.
        generatedAt: PersonalLogBenchmarkFixture.asOf.add(
          Duration(seconds: ++_nonce),
        ),
      );
      PortableDataRestoreReceipt? receipt;
      try {
        final request = await coordinator.prepare(
          packageJson: artifact.canonicalJson,
          ownerScope: 'local_user',
          effectiveOwnerScope: 'local_user',
          scopeKind: 'local_device_account',
          foodCatalog: fixture.foods,
          medicationCatalog: fixture.drugs,
          authorize: () => _authorized,
        );
        receipt = await coordinator.commit(
          request: request,
          currentPackageJson: artifact.canonicalJson,
          explicitlyConfirmed: true,
          authorize: () => _authorized,
        );
        await preferences.reload();
        await _requireFixture(fixture);
        nonces.add({
          'nonce': _nonce,
          'packageJsonSha256': request.packageJsonSha256,
        });
        return fixture.meals.length + fixture.intakes.length;
      } finally {
        if (receipt != null) {
          await store.rollbackPortableRestore(
            receipt,
            ownerScope: 'local_user',
            authorize: () => _authorized,
          );
        }
        await preferences.reload();
        await _requireEmpty();
      }
    });
    if (!_authorized) {
      throw StateError('persistent_benchmark_final_lease_changed');
    }
    await preferences.reload();
    await _requireEmpty();
    await _requireNoCareOrDraft();
    report['restoreFinalStateVerifiedEmpty'] = true;
    return report;
  }
}

/// Restores may canonicalize list order. Identity and every original value,
/// including invalid/missing fields, must still match without normalization.
bool benchmarkRecordsMatchById(
  Iterable<Map<String, dynamic>> actual,
  Iterable<Map<String, dynamic>> expected,
) {
  Map<String, String>? indexed(Iterable<Map<String, dynamic>> records) {
    final result = <String, String>{};
    for (final record in records) {
      final id = record['id'];
      if (id is! String || result.containsKey(id)) return null;
      result[id] = portableRestoreCanonicalJson(record);
    }
    return result;
  }

  final actualById = indexed(actual);
  final expectedById = indexed(expected);
  return actualById != null &&
      expectedById != null &&
      actualById.length == expectedById.length &&
      expectedById.entries.every(
        (entry) => actualById[entry.key] == entry.value,
      );
}

/// Check before constructing services, which may initialize catalogue storage.
/// A populated, unmarked origin is rejected even when its record lists are empty.
void requireDisposableBenchmarkOrigin({
  required Set<String> existingKeys,
  required String? marker,
  required String expectedMarker,
}) {
  if (marker != null && marker != expectedMarker) {
    throw StateError('persistent_benchmark_foreign_or_stale_marker');
  }
  if (marker == null && existingKeys.isNotEmpty) {
    throw StateError('persistent_benchmark_requires_initially_empty_origin');
  }
}
