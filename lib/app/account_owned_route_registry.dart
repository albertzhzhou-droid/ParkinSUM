import 'package:flutter/material.dart';

/// Tracks imperative routes that were opened while an account owned the
/// visible patient-data session.
///
/// The declarative root route is deliberately excluded. Every route pushed on
/// top of it while [activeUserScope] is non-null is associated with that exact
/// scope and can be removed synchronously when the authenticated UID changes.
class AccountOwnedRouteRegistry {
  final Map<Route<dynamic>, String> _owners = <Route<dynamic>, String>{};

  String? activeUserScope;

  late final NavigatorObserver observer = _AccountOwnedRouteObserver(this);

  void removeRoutesOwnedBy(String userScope, NavigatorState? navigator) {
    if (navigator == null) return;
    final ownedRoutes = _owners.entries
        .where((entry) => entry.value == userScope)
        .map((entry) => entry.key)
        .toList(growable: false)
        .reversed;
    for (final route in ownedRoutes) {
      _owners.remove(route);
      if (route.isActive) {
        navigator.removeRoute(route);
      }
    }
  }

  void _didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final userScope = activeUserScope;
    // The first route is the RouterDelegate's durable root page. It must stay
    // mounted so the declarative auth/onboarding state can replace its child.
    if (previousRoute == null || userScope == null) return;
    _owners[route] = userScope;
  }

  void _didRemove(Route<dynamic> route) {
    _owners.remove(route);
  }

  void _didReplace(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final owner = oldRoute == null ? activeUserScope : _owners.remove(oldRoute);
    if (newRoute != null && owner != null) {
      _owners[newRoute] = owner;
    }
  }
}

class _AccountOwnedRouteObserver extends NavigatorObserver {
  _AccountOwnedRouteObserver(this.registry);

  final AccountOwnedRouteRegistry registry;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    registry._didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    registry._didRemove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    registry._didRemove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    registry._didReplace(newRoute, oldRoute);
  }
}
