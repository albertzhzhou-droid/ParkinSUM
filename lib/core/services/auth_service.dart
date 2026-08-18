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

  bool get currentUserEmailVerified;

  List<String> get currentUserProviderIds;

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

  Future<void> sendPasswordResetEmail({
    required String email,
    required String languageCode,
  });

  Future<void> sendEmailVerification({required String languageCode});

  Future<AuthUser?> reloadCurrentUser();

  /// Re-establishes recent-login proof before changing a password.
  ///
  /// Implementations must never persist, log, or surface either password.
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// 退出登录
  Future<void> signOut();
}

class AuthUser {
  final String uid;
  final String? email;
  final bool emailVerified;
  final List<String> providerIds;

  const AuthUser({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.providerIds = const <String>[],
  });
}

enum AccountSecurityFailure {
  notSignedIn,
  passwordProviderUnavailable,
  wrongCurrentPassword,
  weakNewPassword,
  tooManyAttempts,
  recentLoginExpired,
  serviceUnavailable,
  unknown,
}

/// A deliberately provider-neutral failure that is safe to map to UI copy.
class AccountSecurityException implements Exception {
  const AccountSecurityException(this.failure);

  final AccountSecurityFailure failure;

  @override
  String toString() => 'AccountSecurityException(${failure.name})';
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
  bool get currentUserEmailVerified => true;

  @override
  List<String> get currentUserProviderIds => const <String>['local'];

  @override
  Stream<AuthUser?> get authStateChanges async* {
    final userId = _userId;
    if (userId != null) {
      yield AuthUser(uid: userId, providerIds: currentUserProviderIds);
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
  Future<void> sendPasswordResetEmail({
    required String email,
    required String languageCode,
  }) async {
    throw UnsupportedError('Password recovery is unavailable in local mode.');
  }

  @override
  Future<void> sendEmailVerification({required String languageCode}) async {
    throw UnsupportedError('Email verification is unavailable in local mode.');
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    final userId = _userId;
    return userId == null
        ? null
        : AuthUser(
            uid: userId,
            emailVerified: true,
            providerIds: currentUserProviderIds,
          );
  }

  @override
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    throw UnsupportedError('Password changes are unavailable in local mode.');
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
  bool get currentUserEmailVerified =>
      _auth.currentUser?.emailVerified ?? false;

  @override
  List<String> get currentUserProviderIds => _providerIds(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      FirebaseBackend.ensureInitialized().asStream().asyncExpand(
        (_) => _auth.authStateChanges().map(
          (user) => user == null
              ? null
              : AuthUser(
                  uid: user.uid,
                  email: user.email,
                  emailVerified: user.emailVerified,
                  providerIds: _providerIds(user),
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
  Future<void> sendPasswordResetEmail({
    required String email,
    required String languageCode,
  }) async {
    await FirebaseBackend.ensureInitialized();
    await _auth.setLanguageCode(_languageFamily(languageCode));
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendEmailVerification({required String languageCode}) async {
    await FirebaseBackend.ensureInitialized();
    final user = _auth.currentUser;
    if (user == null) throw StateError('Firebase user is not signed in.');
    if (user.emailVerified) return;
    await _auth.setLanguageCode(_languageFamily(languageCode));
    await user.sendEmailVerification();
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    await FirebaseBackend.ensureInitialized();
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser;
    return refreshed == null
        ? null
        : AuthUser(
            uid: refreshed.uid,
            email: refreshed.email,
            emailVerified: refreshed.emailVerified,
            providerIds: _providerIds(refreshed),
          );
  }

  @override
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await FirebaseBackend.ensureInitialized();
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountSecurityException(AccountSecurityFailure.notSignedIn);
    }
    final email = user.email;
    if (email == null || !_providerIds(user).contains('password')) {
      throw const AccountSecurityException(
        AccountSecurityFailure.passwordProviderUnavailable,
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw AccountSecurityException(_mapAccountSecurityFailure(error.code));
    } catch (_) {
      throw const AccountSecurityException(AccountSecurityFailure.unknown);
    }
  }

  @override
  Future<void> signOut() async {
    await FirebaseBackend.ensureInitialized();
    await _auth.signOut();
  }
}

String _languageFamily(String localeTag) => localeTag.split('-').first;

List<String> _providerIds(User? user) {
  if (user == null) return const <String>[];
  final ids =
      user.providerData
          .map((profile) => profile.providerId)
          .where((providerId) => providerId.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  return List<String>.unmodifiable(ids);
}

AccountSecurityFailure _mapAccountSecurityFailure(String code) {
  return switch (code) {
    'wrong-password' ||
    'invalid-credential' ||
    'user-mismatch' => AccountSecurityFailure.wrongCurrentPassword,
    'weak-password' => AccountSecurityFailure.weakNewPassword,
    'too-many-requests' => AccountSecurityFailure.tooManyAttempts,
    'requires-recent-login' => AccountSecurityFailure.recentLoginExpired,
    'network-request-failed' ||
    'internal-error' => AccountSecurityFailure.serviceUnavailable,
    'user-not-found' || 'user-disabled' => AccountSecurityFailure.notSignedIn,
    _ => AccountSecurityFailure.unknown,
  };
}
