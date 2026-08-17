import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/main_shell/main_tab_route.dart';

void main() {
  const parser = MainTabRouteInformationParser();

  test('tab ids and indexes have a stable round trip', () {
    for (final route in MainTabRoute.values) {
      expect(MainTabRoute.fromId(route.id).index, route.index);
      expect(MainTabRoute.fromIndex(route.index).id, route.id);
    }
    expect(MainTabRoute.fromId('future-tab'), MainTabRoute.home);
    expect(MainTabRoute.fromIndex(99), MainTabRoute.home);
  });

  test('canonical app URLs restore tabs and unknown paths fail safe', () {
    expect(MainTabRoute.fromUri(Uri.parse('/app/timeline')).id, 'timeline');
    expect(MainTabRoute.fromUri(Uri.parse('/catalog')).id, 'catalog');
    expect(MainTabRoute.fromUri(Uri.parse('/')).id, 'home');
    expect(MainTabRoute.fromUri(Uri.parse('/unknown/path')).id, 'home');
  });

  test('route information parser restores canonical URL', () async {
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/app/next-meal')),
    );
    final restored = parser.restoreRouteInformation(route);

    expect(route.id, 'next-meal');
    expect(restored.uri.path, '/app/next-meal');
  });
}
