import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_firestore.dart';
import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid profile scope performs no cloud API calls', () async {
    final probe = _CloudProbe();
    final store = _store(probe, _Auth('owner_a'));
    await expectLater(
      store.saveUserProfileForSession(
        _profile('owner_a'),
        scope: _scope('owner_a', () => false),
      ),
      throwsA(isA<UserPreferenceWriteScopeChanged>()),
    );
    expect(probe.collections, isEmpty);
    expect(probe.writes, isEmpty);
  });

  test('foreign profile is rejected before selecting any owner path', () async {
    final probe = _CloudProbe();
    await expectLater(
      _store(probe, _Auth('owner_a')).saveUserProfileForSession(
        _profile('owner_b'),
        scope: _scope('owner_a', () => true),
      ),
      throwsStateError,
    );
    expect(probe.collections, isEmpty);
  });

  test(
    'snapshot await cannot switch medication writes or history to a new owner',
    () async {
      final probe = _CloudProbe();
      final auth = _Auth('owner_a');
      probe.afterSnapshot = () async {
        auth.uid = 'owner_b';
      };
      await expectLater(
        _store(probe, auth).saveActiveDrugIdsForSession([
          'new_drug',
        ], scope: _scope('owner_a', () => true)),
        throwsA(isA<UserPreferenceWriteScopeChanged>()),
      );
      expect(
        probe.collections.every((path) => path.startsWith('users/owner_a/')),
        true,
      );
      expect(probe.writes, isEmpty);
      expect(probe.commits, 0);
    },
  );

  test(
    'same UID with an invalidated session refuses writes after snapshot await',
    () async {
      final probe = _CloudProbe();
      var valid = true;
      probe.afterSnapshot = () async {
        valid = false;
      };
      await expectLater(
        _store(probe, _Auth('owner_a')).saveActiveDrugIdsForSession([
          'new_drug',
        ], scope: _scope('owner_a', () => valid)),
        throwsA(isA<UserPreferenceWriteScopeChanged>()),
      );
      expect(probe.commits, 0);
      expect(probe.writes, isEmpty);
    },
  );

  test(
    'valid selection is one complete batch with matching owner history',
    () async {
      final probe = _CloudProbe();
      probe.existing = {
        'old_drug': {'id': 'old_drug'},
      };
      await _store(probe, _Auth('owner_a')).saveActiveDrugIdsForSession([
        'new_a',
        'new_b',
      ], scope: _scope('owner_a', () => true));
      expect(probe.commits, 1);
      expect(probe.writes, hasLength(6));
      expect(
        probe.writes.every((row) => row.path.startsWith('users/owner_a/')),
        true,
      );
      expect(
        probe.writes.where((row) => row.operation == 'delete').single.path,
        'users/owner_a/active_drugs/old_drug',
      );
      final history = probe.writes.where(
        (row) => row.path.contains('/record_history/'),
      );
      expect(history, hasLength(3));
      expect(history.map((row) => row.data!['record_id']).toSet(), {
        'old_drug',
        'new_a',
        'new_b',
      });
      expect(
        history.every((row) => row.data!['created_at'] is FieldValue),
        true,
      );
    },
  );

  test(
    'local 500-write budget rejects a prefix instead of dispatching split batches',
    () async {
      final probe = _CloudProbe();
      await expectLater(
        _store(probe, _Auth('owner_a')).saveActiveDrugIdsForSession(
          List.generate(251, (index) => 'drug_$index'),
          scope: _scope('owner_a', () => true),
        ),
        throwsUnsupportedError,
      );
      expect(probe.commits, 0);
      expect(probe.writes, isEmpty);
    },
  );

  test(
    'late profile acknowledgement retains its original dispatched owner',
    () async {
      final probe = _CloudProbe();
      final auth = _Auth('owner_a');
      final dispatched = Completer<void>();
      final acknowledgement = Completer<void>();
      probe.afterProfileDispatch = () async {
        dispatched.complete();
        await acknowledgement.future;
      };
      var valid = true;
      final pending = _store(probe, auth).saveUserProfileForSession(
        _profile('owner_a'),
        scope: _scope('owner_a', () => valid),
      );
      await dispatched.future;
      auth.uid = 'owner_b';
      valid = false;
      acknowledgement.complete();
      await pending;
      expect(probe.writes, hasLength(1));
      expect(probe.writes.single.path, 'users/owner_a/profile/current');
      expect(probe.writes.single.data!['patientId'], 'owner_a');
      // A dispatched call is not retrospectively called cancelled. AppState
      // separately rejects publication of this acknowledgement to a new session.
    },
  );
}

FirestoreAppDatabase _store(_CloudProbe probe, _Auth auth) =>
    FirestoreAppDatabase(authService: auth, firestore: _Firestore(probe));
UserProfile _profile(String owner) =>
    UserProfile.defaults().copyWith(patientId: owner);
UserPreferenceWriteScope _scope(String owner, bool Function() valid) =>
    UserPreferenceWriteScope(
      ownerUid: owner,
      sessionEpoch: 1,
      isCurrent: valid,
    );

/// Strict recording doubles run actual FirestoreAppDatabase code. They do not
/// emulate cloud persistence, network credentials, offline queues or rules.
class _CloudProbe {
  final collections = <String>[];
  final writes =
      <({String path, String operation, Map<String, dynamic>? data})>[];
  Map<String, Map<String, dynamic>> existing = {};
  Future<void> Function()? afterSnapshot;
  Future<void> Function()? afterProfileDispatch;
  int commits = 0;
  int historySequence = 0;
}

class _Auth implements AuthService {
  _Auth(this.uid);
  String? uid;
  @override
  String? get currentUserId => uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.probe);
  final _CloudProbe probe;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    probe.collections.add(path);
    return _Collection(probe, path);
  }

  @override
  WriteBatch batch() => _Batch(probe);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only call recorder; no SDK implementation or cloud behavior is inferred.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.probe, this.path);
  final _CloudProbe probe;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(probe, '$path/${id ?? 'history_${++probe.historySequence}'}');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = [
      for (final entry in probe.existing.entries)
        _QueryDocument(entry.key, entry.value),
    ];
    await probe.afterSnapshot?.call();
    return _Snapshot(docs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only call recorder for the production store's injected SDK interface.
// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.probe, this.path);
  final _CloudProbe probe;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    probe.writes.add((path: path, operation: 'set', data: Map.of(data)));
    await probe.afterProfileDispatch?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only snapshot with explicit data; it does not emulate query semantics.
// ignore: subtype_of_sealed_class
class _QueryDocument implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => Map.of(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batch implements WriteBatch {
  _Batch(this.probe);
  final _CloudProbe probe;
  final commands =
      <({String path, String operation, Map<String, dynamic>? data})>[];
  @override
  void delete(DocumentReference document) =>
      commands.add((path: document.path, operation: 'delete', data: null));
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      commands.add((
        path: document.path,
        operation: 'set',
        data: Map<String, dynamic>.from(data as Map),
      ));
  @override
  Future<void> commit() async {
    probe.commits += 1;
    probe.writes.addAll(commands);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
