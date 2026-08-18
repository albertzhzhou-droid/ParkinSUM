library;

/// Supplies an intrinsic runtime type that an external subtype cannot spoof by
/// overriding [Object.runtimeType]. The getter is library-private, while the
/// public predicate below is the only supported inspection surface.
mixin RegisteredAlgorithmComponentIdentity {
  _ComponentIdentityToken get _identityToken => _componentIdentityToken;

  Type get _intrinsicRuntimeType => super.runtimeType;
}

/// Returns true only when [component] inherited this library's private
/// capability token and its intrinsic runtime type equals [expectedType].
bool hasExactRegisteredAlgorithmComponentType({
  required Object component,
  required Type expectedType,
}) {
  if (component is! RegisteredAlgorithmComponentIdentity) return false;
  try {
    return identical(component._identityToken, _componentIdentityToken) &&
        component._intrinsicRuntimeType == expectedType;
  } on Object {
    // An `implements` forgery may route the private witness getters through
    // noSuchMethod. It cannot construct this library-private token, so treat
    // any missing/ill-typed witness as unattested rather than propagating it.
    return false;
  }
}

final class _ComponentIdentityToken {
  const _ComponentIdentityToken();
}

const _componentIdentityToken = _ComponentIdentityToken();
