import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/interaction_rule_record.dart';
import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/recoverable_user_event.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firebase_backend.dart';
import '../services/firebase_user_data_paths.dart';
import 'app_database.dart';
import 'firestore_collection_diff.dart';
import 'recoverable_user_event_store.dart';

/// Firestore-backed app database for the existing AppDatabase seam.
///
/// Layout:
/// app_catalog/foods/rows/{foodId}
/// app_catalog/medications/rows/{drugId}
/// app_catalog/interaction_rules/rows/{ruleId}
/// users/{uid}/profile/current
/// users/{uid}/app_meta/{key}
/// users/{uid}/meals/{mealId}
/// users/{uid}/intakes/{intakeId}
/// users/{uid}/active_drugs/{drugId}
class FirestoreAppDatabase implements AppDatabase, RecoverableUserEventStore {
  final AuthService authService;
  final FirebaseFirestore? _providedFirestore;
  final bool seedCatalogOnInitialize;

  FirestoreAppDatabase({
    required this.authService,
    FirebaseFirestore? firestore,
    this.seedCatalogOnInitialize = false,
  }) : _providedFirestore = firestore;

  FirebaseFirestore get firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  Future<String> _requireUid() async {
    await FirebaseBackend.ensureInitialized();
    final uid = authService.currentUserId;
    if (uid == null) {
      throw StateError('Firebase user is not signed in.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _catalog(String table) {
    return firestore.collection('app_catalog').doc(table).collection('rows');
  }

  Future<CollectionReference<Map<String, dynamic>>> _userRows(
    String table,
  ) async {
    final uid = await _requireUid();
    final paths = FirebaseUserDataPaths(uid);
    return firestore.collection(paths.collection(table));
  }

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) async {
    await FirebaseBackend.ensureInitialized();
    if (!seedCatalogOnInitialize) return;
    final batch = firestore.batch();
    for (final food in seedFoods) {
      batch.set(_catalog('foods').doc(food.id), food.toJson());
    }
    for (final medication in seedMedications) {
      batch.set(
        _catalog('medications').doc(medication.id),
        medication.toJson(),
      );
    }
    for (final rule in seedRules) {
      batch.set(_catalog('interaction_rules').doc(rule.id), rule.toJson());
    }
    await batch.commit();
  }

  @override
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) async {
    final uid = await _requireUid();
    if (commit.profile.patientId != uid) {
      throw StateError('Onboarding account changed before persistence.');
    }
    final paths = FirebaseUserDataPaths(uid);
    final profile = firestore.collection(paths.collection('profile'));
    final metadata = firestore.collection(paths.collection('app_meta'));
    final activeDrugs = firestore.collection(paths.collection('active_drugs'));
    final intakes = firestore.collection(paths.collection('intakes'));
    final history = firestore.collection(paths.collection('record_history'));
    final marker = metadata.doc('onboarded');

    final markerSnapshot = await marker.get();
    if (markerSnapshot.data()?['value'] == true &&
        markerSnapshot.data()?['operation_id'] == commit.operationId) {
      return;
    }

    final activeSnapshot = await activeDrugs.get();
    final intakeSnapshot = await intakes.get();
    final activePlan = planFirestoreCollectionSync(
      existing: <String, Map<String, dynamic>>{
        for (final doc in activeSnapshot.docs) doc.id: doc.data(),
      },
      desired: <String, Map<String, dynamic>>{
        for (final id in commit.activeDrugIds) id: <String, dynamic>{'id': id},
      },
    );
    final intakePlan = planFirestoreCollectionSync(
      existing: <String, Map<String, dynamic>>{
        for (final doc in intakeSnapshot.docs) doc.id: doc.data(),
      },
      desired: <String, Map<String, dynamic>>{
        for (final intake in commit.intakes)
          intake.id: <String, dynamic>{
            ...intake.toJson(),
            'takenAtIso': intake.takenAt.toIso8601String(),
          },
      },
    );
    final mutations = <_FirestoreRowMutation>[
      for (final id in activePlan.removals)
        _FirestoreRowMutation.delete(activeDrugs.doc(id)),
      for (final entry in activePlan.upserts.entries)
        _FirestoreRowMutation.set(activeDrugs.doc(entry.key), entry.value),
      for (final id in intakePlan.removals)
        _FirestoreRowMutation.delete(intakes.doc(id)),
      for (final entry in intakePlan.upserts.entries)
        _FirestoreRowMutation.set(intakes.doc(entry.key), entry.value),
    ];
    final writeCount = 2 + (mutations.length * 2);
    if (writeCount > 500) {
      throw StateError(
        'Atomic onboarding commit exceeds the Firestore write limit.',
      );
    }

    final batch = firestore.batch();
    batch.set(
      profile.doc('current'),
      commit.profile.copyWith(patientId: uid).toJson(),
    );
    for (final mutation in mutations) {
      if (mutation.data == null) {
        batch.delete(mutation.reference);
      } else {
        batch.set(mutation.reference, mutation.data!);
      }
      final collectionName = mutation.reference.parent.id;
      batch.set(history.doc(), <String, dynamic>{
        'schema_version': 1,
        'collection': collectionName,
        'record_id': mutation.reference.id,
        'operation': mutation.data == null ? 'delete' : 'set',
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    batch.set(marker, <String, dynamic>{
      'value': true,
      'operation_id': commit.operationId,
      'stage': atomicOnboardingCommitStageCommitted,
      'schema_version': atomicOnboardingCommitSchemaVersion,
      'owner_uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'purpose': 'atomic_onboarding_commit',
    });
    await batch.commit();
  }

  @override
  Future<List<String>> loadActiveDrugIds() async {
    final snapshot = await (await _userRows('active_drugs')).get();
    return snapshot.docs.map((doc) => doc.id).toList(growable: false);
  }

  @override
  Future<List<FoodItem>> loadFoods() async {
    final snapshot = await _catalog('foods').orderBy('name').get();
    return snapshot.docs
        .map((doc) => FoodItem.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<Intake>> loadIntakes() async {
    final snapshot = await (await _userRows(
      'intakes',
    )).orderBy('takenAtIso', descending: true).get();
    return snapshot.docs
        .map((doc) => Intake.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async {
    final snapshot = await _catalog('interaction_rules').get();
    return snapshot.docs
        .map((doc) => InteractionRuleRecord.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<DrugDefinition>> loadMedications() async {
    final snapshot = await _catalog('medications').orderBy('genericName').get();
    return snapshot.docs
        .map((doc) => DrugDefinition.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final snapshot = await (await _userRows(
      'meals',
    )).orderBy('eatenAtIso', descending: true).get();
    return snapshot.docs
        .map((doc) => Meal.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<bool> loadOnboarded() async {
    final doc = await (await _userRows('app_meta')).doc('onboarded').get();
    return doc.data()?['value'] == true;
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    final doc = await (await _userRows('profile')).doc('current').get();
    final data = doc.data();
    if (data == null) return UserProfile.defaults();
    return UserProfile.fromJson(data);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    final rows = await _userRows('active_drugs');
    await _syncRows('active_drugs', rows, {
      for (final id in ids) id: {'id': id},
    });
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    final rows = await _userRows('intakes');
    await _syncRows('intakes', rows, {
      for (final intake in intakes)
        intake.id: {
          ...intake.toJson(),
          'takenAtIso': intake.takenAt.toIso8601String(),
        },
    });
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    final rows = await _userRows('meals');
    await _syncRows('meals', rows, {
      for (final meal in meals)
        meal.id: {
          ...meal.toJson(),
          'eatenAtIso': meal.eatenAt.toIso8601String(),
        },
    });
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    final marker = (await _userRows('app_meta')).doc('onboarded');
    if (value) {
      await marker.set(<String, dynamic>{
        'value': true,
      }, SetOptions(merge: true));
    } else {
      // A reset intentionally clears the completed operation marker so a new
      // onboarding request is not mistaken for an acknowledged retry.
      await marker.set(<String, dynamic>{'value': false});
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final uid = await _requireUid();
    final rows = firestore.collection(
      FirebaseUserDataPaths(uid).collection('profile'),
    );
    await rows.doc('current').set(profile.copyWith(patientId: uid).toJson());
  }

  Future<void> _syncRows(
    String collectionName,
    CollectionReference<Map<String, dynamic>> rows,
    Map<String, Map<String, dynamic>> desired,
  ) async {
    final snapshot = await rows.get();
    final existing = <String, Map<String, dynamic>>{
      for (final doc in snapshot.docs) doc.id: doc.data(),
    };
    final plan = planFirestoreCollectionSync(
      existing: existing,
      desired: desired,
    );
    if (plan.isEmpty) return;

    final uid = await _requireUid();
    final history = firestore.collection(
      FirebaseUserDataPaths(uid).collection('record_history'),
    );

    final mutations = <_FirestoreRowMutation>[
      for (final id in plan.removals)
        _FirestoreRowMutation.delete(rows.doc(id)),
      for (final entry in plan.upserts.entries)
        _FirestoreRowMutation.set(rows.doc(entry.key), entry.value),
    ];

    // Each row mutation is paired atomically with an append-only history row.
    // Firestore batches permit at most 500 writes, so 220 pairs leave headroom.
    for (var offset = 0; offset < mutations.length; offset += 220) {
      final batch = firestore.batch();
      final end = (offset + 220).clamp(0, mutations.length);
      for (final mutation in mutations.sublist(offset, end)) {
        if (mutation.data == null) {
          batch.delete(mutation.reference);
        } else {
          batch.set(mutation.reference, mutation.data!);
        }
        batch.set(history.doc(), {
          'schema_version': 1,
          'collection': collectionName,
          'record_id': mutation.reference.id,
          'operation': mutation.data == null ? 'delete' : 'set',
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  @override
  Future<List<RecoverableUserEventRevision>>
  loadRecoverableUserEventHistory() async {
    final snapshot = await (await _userRows(
      'record_history',
    )).orderBy('created_at', descending: true).limit(500).get();
    final revisions = snapshot.docs
        .where((doc) => doc.data()['revision'] is Map)
        .map(
          (doc) => RecoverableUserEventRevision.fromJson(
            Map<String, dynamic>.from(doc.data()['revision'] as Map),
          ),
        )
        .toList(growable: false);
    revisions.sort((left, right) {
      final time = right.recordedAtUtc.compareTo(left.recordedAtUtc);
      return time != 0 ? time : right.historyId.compareTo(left.historyId);
    });
    return revisions;
  }

  @override
  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  ) async {
    final revision = mutation.revision..validate();
    final uid = await _requireUid();
    final paths = FirebaseUserDataPaths(uid);
    final collectionName = switch (revision.eventType) {
      RecoverableUserEventType.meal => 'meals',
      RecoverableUserEventType.intake => 'intakes',
    };
    final row = firestore
        .collection(paths.collection(collectionName))
        .doc(revision.recordId);
    final history = firestore
        .collection(paths.collection('record_history'))
        .doc(revision.operationId);

    await firestore.runTransaction((transaction) async {
      final historySnapshot = await transaction.get(history);
      final rowSnapshot = await transaction.get(row);
      final currentPayload = _firestoreCurrentEventPayload(
        revision.eventType,
        rowSnapshot.data(),
      );
      final currentDigest = recoverableUserEventPayloadDigest(currentPayload);
      if (historySnapshot.exists) {
        final prior = historySnapshot.data()?['revision'];
        if (prior is! Map ||
            RecoverableUserEventRevision.fromJson(
                  Map<String, dynamic>.from(prior),
                ).historyId !=
                revision.historyId ||
            currentDigest != revision.afterDigest) {
          throw RecoverableUserEventConflict(
            recordId: revision.recordId,
            expectedDigest: revision.afterDigest,
            actualDigest: currentDigest,
          );
        }
        return;
      }
      if (currentDigest != mutation.expectedCurrentDigest) {
        throw RecoverableUserEventConflict(
          recordId: revision.recordId,
          expectedDigest: mutation.expectedCurrentDigest,
          actualDigest: currentDigest,
        );
      }
      final next = revision.afterPayload;
      if (next == null) {
        transaction.delete(row);
      } else {
        transaction.set(row, <String, dynamic>{
          ...next,
          if (revision.eventType == RecoverableUserEventType.meal)
            'eatenAtIso': next['eatenAt'],
          if (revision.eventType == RecoverableUserEventType.intake)
            'takenAtIso': next['takenAt'],
        });
      }
      transaction.set(history, <String, dynamic>{
        'schema_version': recoverableUserEventSchemaVersion,
        'collection': collectionName,
        'record_id': revision.recordId,
        'operation': revision.mutationType.name,
        'operation_id': revision.operationId,
        'before_digest': revision.beforeDigest,
        'after_digest': revision.afterDigest,
        'revision': revision.toJson(),
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, Object?>? _firestoreCurrentEventPayload(
    RecoverableUserEventType eventType,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    return switch (eventType) {
      RecoverableUserEventType.meal => Map<String, Object?>.from(
        Meal.fromJson(data).toJson(),
      ),
      RecoverableUserEventType.intake => Map<String, Object?>.from(
        Intake.fromJson(data).toJson(),
      ),
    };
  }
}

class _FirestoreRowMutation {
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? data;

  const _FirestoreRowMutation.set(this.reference, this.data);
  const _FirestoreRowMutation.delete(this.reference) : data = null;
}
