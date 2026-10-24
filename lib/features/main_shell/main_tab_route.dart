import 'package:flutter/widgets.dart';

class MainTabRoute {
  const MainTabRoute._(this.id, this.index);

  final String id;
  final int index;

  static const MainTabRoute home = MainTabRoute._('home', 0);
  static const MainTabRoute nextMeal = MainTabRoute._('next-meal', 1);
  static const MainTabRoute timeline = MainTabRoute._('timeline', 2);
  static const MainTabRoute analytics = MainTabRoute._('analytics', 3);
  static const MainTabRoute medications = MainTabRoute._('medications', 4);
  static const MainTabRoute catalog = MainTabRoute._('catalog', 5);

  /// Next meal → Advanced (dishes and preparation). A sub-route shown in
  /// the Next-meal tab's place; it shares that tab's index.
  static const MainTabRoute nextMealAdvanced = MainTabRoute._(
    'next-meal/advanced',
    1,
  );

  static const List<MainTabRoute> values = <MainTabRoute>[
    home,
    nextMeal,
    timeline,
    analytics,
    medications,
    catalog,
  ];

  /// Routes below a tab. Not part of [values], whose indexes are unique.
  static const List<MainTabRoute> subRoutes = <MainTabRoute>[nextMealAdvanced];

  /// The tab this route belongs to (itself for a tab).
  MainTabRoute get tab => fromIndex(index);

  static MainTabRoute fromId(String? id) => values
      .followedBy(subRoutes)
      .firstWhere((route) => route.id == id, orElse: () => home);

  static MainTabRoute fromIndex(int index) =>
      index >= 0 && index < values.length ? values[index] : home;

  static MainTabRoute fromUri(Uri uri) {
    final segments = uri.pathSegments.where((value) => value.isNotEmpty);
    final parts = segments.toList(growable: false);
    if (parts.isEmpty) return home;
    if (parts.length == 1) return fromId(parts.first);
    if (parts.first == 'app') {
      if (parts.length > 2) {
        final sub = fromId('${parts[1]}/${parts[2]}');
        if (sub != home) return sub;
      }
      return fromId(parts[1]);
    }
    return home;
  }

  Uri get uri => Uri(path: '/app/$id');
}

class MainTabRouteInformationParser
    extends RouteInformationParser<MainTabRoute> {
  const MainTabRouteInformationParser();

  @override
  Future<MainTabRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async => MainTabRoute.fromUri(routeInformation.uri);

  @override
  RouteInformation restoreRouteInformation(MainTabRoute configuration) =>
      RouteInformation(uri: configuration.uri);
}
