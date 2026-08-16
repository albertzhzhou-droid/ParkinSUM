import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:provider/provider.dart';

/// Shared harness for pumping real feature pages in widget tests.
///
/// Feature pages need three things a bare `pumpWidget` does not give them:
/// an `AppState` provider, a working asset bundle (brand images), and a
/// viewport big enough that phone-sized layouts do not overflow. This helper
/// supplies all three so smoke tests stay one-liners.
///
/// Educational prototype only; local mode; synthetic/demo data only. No PHI,
/// no network, no Firebase (the default build is local mode — see
/// test/local_mode_network_isolation_test.dart).

/// Builds a local-mode [AppState].
///
/// `Services.createDefault()` kicks off a background sqlite open that has no
/// platform support on the test VM. That failure is unrelated to anything the
/// page tests assert, so it is absorbed by a guarded zone; the synchronous
/// service wiring the pages actually read is unaffected.
AppState createTestAppState() {
  AppState? state;
  runZonedGuarded(() {
    state = AppState(services: Services.createDefault());
  }, (_, __) {
    // Local sqlite init is unavailable in VM tests; intentionally ignored.
  });
  if (state == null) {
    throw StateError('Could not construct a local-mode AppState for tests.');
  }
  return state!;
}

/// Pumps [page] inside a provider + stub-asset + phone-viewport scaffold.
///
/// Pass [settle] to run `pumpAndSettle` instead of a single frame; leave it
/// false for pages that keep an animation or a pending future alive.
Future<AppState> pumpFeaturePage(
  WidgetTester tester,
  Widget page, {
  AppState? state,
  bool settle = false,
  Size surfaceSize = const Size(1170, 2532),
  double devicePixelRatio = 3.0,
}) async {
  final appState = state ?? createTestAppState();

  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        home: DefaultAssetBundle(bundle: StubAssetBundle(), child: page),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  } else {
    await tester.pump();
  }
  return appState;
}

/// Fails the test if the pumped widget tree raised a Flutter error or is
/// showing an error widget. `pumpWidget` records exceptions rather than
/// throwing, so without this a broken page can "pass" silently.
void expectNoWidgetErrors({String? reason}) {
  final error = takePendingWidgetException();
  expect(error, isNull,
      reason: reason ?? 'page raised ${error.runtimeType}: $error');
  expect(find.byType(ErrorWidget), findsNothing,
      reason: reason ?? 'page rendered an ErrorWidget');
}

/// Reads (and clears) the pending widget-tree exception.
Object? takePendingWidgetException() =>
    TestWidgetsFlutterBinding.instance.takeException();

/// Serves a valid 1x1 transparent PNG for every image asset, plus a minimal
/// `AssetManifest.bin`, so pages with brand images render under flutter_test.
///
/// The manifest matters: `AssetImage` resolves variants through it first, and
/// returning PNG bytes there fails with "Message corrupted".
class StubAssetBundle extends CachingAssetBundle {
  static final Uint8List _onePixelPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR (1x1 RGBA)
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object?>{
        'assets/brand/parkinsum-icon.png': <Object?>[],
        'assets/brand/parkinsum-wordmark.png': <Object?>[],
      })!;
    }
    return ByteData.view(_onePixelPng.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '{}';
}
