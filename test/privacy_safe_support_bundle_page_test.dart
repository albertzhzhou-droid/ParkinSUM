import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/portable_data_export_sink.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/privacy_safe_support_bundle_service.dart';
import 'package:parkinsum_companion/features/settings/privacy_safe_support_bundle_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('preview, copy, and save use one exact reviewed artifact', (
    tester,
  ) async {
    final clipboard = _FakeClipboard();
    final sink = _FakeSink();
    await _pumpPage(tester, clipboard: clipboard, sink: sink);

    await _tap(tester, 'support-generate');
    final preview = tester.widget<SelectableText>(
      find.byKey(const ValueKey('support-exact-preview')),
    );
    expect(preview.data, contains(privacySafeSupportBundleSchema));
    expect(preview.data, contains('"selected_sections"'));
    expect(preview.data, isNot(contains('account-a@example.test')));

    await _tap(tester, 'support-copy');
    await _tap(tester, 'support-save');

    expect(clipboard.writes, [preview.data]);
    expect(sink.contents, [preview.data]);
    expect(sink.fileNames.single, startsWith('parkinsum-support-2026-08-18'));
    expect(
      find.text(
        'A browser download was requested. Confirm the file in your browser.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('deselecting a section invalidates preview and excludes it', (
    tester,
  ) async {
    await _pumpPage(tester, clipboard: _FakeClipboard(), sink: _FakeSink());
    await _tap(tester, 'support-generate');
    expect(find.byKey(const ValueKey('support-exact-preview')), findsOneWidget);

    await _tap(tester, 'support-section-governance');
    expect(find.byKey(const ValueKey('support-exact-preview')), findsNothing);
    await _tap(tester, 'support-generate');
    final preview = tester.widget<SelectableText>(
      find.byKey(const ValueKey('support-exact-preview')),
    );
    expect(preview.data, isNot(contains('"governance"')));
  });

  testWidgets('source revision drift clears preview before copy side effect', (
    tester,
  ) async {
    var snapshot = _snapshot();
    final clipboard = _FakeClipboard();
    await _pumpPage(
      tester,
      clipboard: clipboard,
      sink: _FakeSink(),
      collectSnapshot: () => snapshot,
    );
    await _tap(tester, 'support-generate');
    snapshot = _snapshot(platformFamily: 'android');

    await _tap(tester, 'support-copy');

    expect(clipboard.writes, isEmpty);
    expect(find.byKey(const ValueKey('support-exact-preview')), findsNothing);
    expect(
      find.text(
        'Diagnostics or build state changed. The old preview was cleared; generate it again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('account switch expires delayed save authorization', (
    tester,
  ) async {
    final gate = Completer<void>();
    final sink = _FakeSink(gate: gate);
    final fixture = await _pumpPage(
      tester,
      clipboard: _FakeClipboard(),
      sink: sink,
    );
    await _tap(tester, 'support-generate');

    final save = find.byKey(const ValueKey('support-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(sink.started.isCompleted, isTrue);

    await fixture.state.signOut();
    await fixture.state.signInWithEmail(
      email: 'account-b@example.test',
      password: 'not-used-in-local-test',
    );
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(sink.contents, isEmpty);
    expect(find.byKey(const ValueKey('support-exact-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported save falls back to authorized exact copy', (
    tester,
  ) async {
    final clipboard = _FakeClipboard();
    await _pumpPage(
      tester,
      clipboard: clipboard,
      sink: _FakeSink(delivery: 'unsupported'),
    );
    await _tap(tester, 'support-generate');
    final preview = tester.widget<SelectableText>(
      find.byKey(const ValueKey('support-exact-preview')),
    );
    await _tap(tester, 'support-save');

    expect(clipboard.writes, [preview.data]);
    expect(
      find.text(
        'This platform cannot safely create a new file. Exact JSON was copied; no saved file is claimed.',
      ),
      findsOneWidget,
    );
  });
}

final class _Fixture {
  const _Fixture(this.state);

  final AppState state;
}

Future<_Fixture> _pumpPage(
  WidgetTester tester, {
  required _FakeClipboard clipboard,
  required _FakeSink sink,
  PrivacySafeSupportSnapshot Function()? collectSnapshot,
}) async {
  final services = Services.createEphemeral();
  await services.ready;
  await services.userDataService.saveOnboarded(true);
  final state = AppState(services: services);
  addTearDown(state.dispose);
  await state.bootstrap();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: PrivacySafeSupportBundlePage(
          clipboard: clipboard,
          exportSink: sink,
          collectSnapshot: collectSnapshot ?? _snapshot,
          now: () => DateTime.utc(2026, 8, 18, 12),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Fixture(state);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _FakeClipboard implements PrivacySafeSupportClipboard {
  final List<String> writes = [];

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('authorization_expired');
    writes.add(text);
  }
}

final class _FakeSink extends PortableDataExportSink {
  _FakeSink({this.gate, this.delivery = 'browser_download'});

  final Completer<void>? gate;
  final String delivery;
  final Completer<void> started = Completer<void>();
  final List<String> contents = [];
  final List<String> fileNames = [];

  @override
  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }
    this.contents.add(contents);
    fileNames.add(fileName);
    return PortableDataExportResult(
      delivery: delivery,
      location: null,
      userVisible: delivery != 'unsupported',
    );
  }
}

PrivacySafeSupportSnapshot _snapshot({String platformFamily = 'web'}) =>
    PrivacySafeSupportSnapshot(
      build: const PrivacySafeSupportBuildSnapshot(
        appVersion: '0.2.0',
        buildNumber: '2',
        buildCommitSha256: 'unavailable',
        backendMode: 'local',
        environment: 'prod',
        algorithmConfigurationSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        algorithmSourceBundleSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      platform: PrivacySafeSupportPlatformSnapshot(
        platformFamily: platformFamily,
        scheduledNotificationsSupported: platformFamily == 'android',
        protectedStoreCapability: platformFamily == 'android'
            ? 'android_keystore_wrapped_aes_gcm_v1'
            : 'web_origin_bound_webcrypto_v1',
        protectedStoreEncryptedAtRest: true,
        protectedStoreHardwareBackingVerified: false,
        firebaseBackendEnabled: false,
        appCheckEnabled: false,
        appCheckDebugEnabled: false,
      ),
      diagnostics: const [
        PrivacySafeSupportDiagnosticCheck(
          checkId: 'mechanistic_replay',
          status: PrivacySafeSupportCheckStatus.pass,
          observedCount: 41,
          expectedCount: 41,
          findingCodes: [],
        ),
      ],
      governance: const PrivacySafeSupportGovernanceSnapshot(
        safeCopyTemplateCount: 20,
        localizationSurfaceCount: 5000,
        replayScenarioCount: 41,
        foodCatalogCount: 25,
        medicationCatalogCount: 8,
        sourceDocumentCount: 62,
        nonLiveSourceDocumentCount: 5,
        placeholderSourceCodeCount: 0,
        ruleCount: 14,
        modelAssumptionCount: 23,
      ),
    );
