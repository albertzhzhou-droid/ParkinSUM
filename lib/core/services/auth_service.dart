import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_backend.dart';

// =====================================================
// AuthService 抽象接口
// =====================================================
//
// 设计原则：
// 1. 上层只依赖这个接口
// 2. 当前使用 LocalAuthService（本地模式）
// 3. 未来要接后端，只需实现 RemoteAuthService
// 4. Services.createDefault() 里替换一行即可
//

abstract class AuthService {
  /// 当前用户ID
  String? get currentUserId;

  String? get currentUserEmail;

  Stream<AuthUser?> get authStateChanges;

  /// 启动时确保存在一个用户
  Future<String> ensureUser();

  Future<String> registerWithEmail({
    required String email,
    required String password,
  });

  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  /// 退出登录
  Future<void> signOut();
}

class AuthUser {
  final String uid;
  final String? email;

  const AuthUser({
    required this.uid,
    this.email,
  });
}

// =====================================================
// 本地实现（当前使用）
// =====================================================
//
// - 不依赖 Firebase
// - 不依赖后端
// - 单机模式
// - 可未来替换
//
class LocalAuthService implements AuthService {
  String? _userId;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail => null;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    final userId = _userId;
    if (userId != null) {
      yield AuthUser(uid: userId);
    }
  }

  @override
  Future<String> ensureUser() async {
    // 本地默认用户
    _userId ??= 'local_user';
    return _userId!;
  }

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) async {
    _userId = 'local_${email.trim().toLowerCase()}';
    return _userId!;
  }

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _userId = 'local_${email.trim().toLowerCase()}';
    return _userId!;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
  }
}

/// Firebase-backed auth implementation.
///
/// Firebase mode requires an explicit email/password session before private
/// user data can be read or written under users/{uid}/...
class FirebaseAuthService implements AuthService {
  final FirebaseAuth? _providedAuth;

  FirebaseAuthService({FirebaseAuth? auth}) : _providedAuth = auth;

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Stream<AuthUser?> get authStateChanges =>
      FirebaseBackend.ensureInitialized().asStream().asyncExpand(
            (_) => _auth.authStateChanges().map(
                  (user) => user == null
                      ? null
                      : AuthUser(
                          uid: user.uid,
                          email: user.email,
                        ),
                ),
          );

  @override
  Future<String> ensureUser() async {
    await FirebaseBackend.ensureInitialized();
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    throw StateError('Firebase user is not signed in.');
  }

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) async {
    await FirebaseBackend.ensureInitialized();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await FirebaseBackend.ensureInitialized();
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<void> signOut() async {
    await FirebaseBackend.ensureInitialized();
    await _auth.signOut();
  }
}
