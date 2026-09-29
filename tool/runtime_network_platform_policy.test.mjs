import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import test from 'node:test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { inspectPlatformNetworkConfiguration } from './runtime_network_platform_policy.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('source inventory matches the versioned egress platform snapshot', () => {
  const policy = JSON.parse(
    readFileSync(path.join(root, 'config/runtime_network_egress_policy.json'), 'utf8'),
  );
  assert.deepEqual(
    inspectPlatformNetworkConfiguration(root),
    policy.platformConfigurationSnapshot,
  );
});

test('compiled Dart evaluator and manifest share the same policy version', () => {
  const policy = JSON.parse(
    readFileSync(path.join(root, 'config/runtime_network_egress_policy.json'), 'utf8'),
  );
  const dartSource = readFileSync(
    path.join(root, 'lib/core/services/runtime_network_egress_policy.dart'),
    'utf8',
  );
  const compiledVersion = dartSource.match(/static const currentVersion = '([^']+)';/)?.[1];
  assert.equal(compiledVersion, policy.policyVersion);
});

test('inventory distinguishes Android source defaults from a resolved merged manifest', () => {
  const observed = inspectPlatformNetworkConfiguration(root);
  assert.equal(observed.android.targetSdkExpression, 'flutter.targetSdkVersion');
  assert.equal(observed.android.resolvedTargetSdk, null);
  assert.equal(observed.android.mergedManifestCapture, 'not_observed');
  assert.deepEqual(observed.android.networkSecurityConfigFiles, []);
  assert(observed.android.sourceManifests.some((manifest) =>
    manifest.path.endsWith('/src/debug/AndroidManifest.xml') &&
    manifest.internetPermission,
  ));
  assert(observed.android.sourceManifests.some((manifest) =>
    manifest.path.endsWith('/src/main/AndroidManifest.xml') &&
    !manifest.internetPermission,
  ));
});

test('Apple inventory records source ATS state and deployment targets without asserting bundle behavior', () => {
  const observed = inspectPlatformNetworkConfiguration(root);
  assert.equal(observed.apple.ios.atsDictionaryPresent, false);
  assert.equal(observed.apple.ios.exceptionDomainsPresent, false);
  assert.deepEqual(observed.apple.ios.deploymentTargets, ['15.0']);
  assert.equal(observed.apple.macos.atsDictionaryPresent, false);
  assert.deepEqual(observed.apple.macos.deploymentTargets, ['12.0']);
  assert.equal(observed.apple.bundleNetworkCapture, 'not_observed');
});

test('Web inventory extracts the Hosting connect-src while retaining response-header uncertainty', () => {
  const observed = inspectPlatformNetworkConfiguration(root);
  assert.equal(observed.web.cspHeaders.length, 1);
  assert.deepEqual(observed.web.cspHeaders[0].sources, [
    "'self'",
    'http://127.0.0.1:*',
    'http://[::1]:*',
    'http://localhost:*',
    'https://*.firebaseapp.com',
    'https://*.firebaseio.com',
    'https://*.googleapis.com',
    'https://api.fda.gov',
    'https://firebaseappcheck.googleapis.com',
    'https://firestore.googleapis.com',
    'https://identitytoolkit.googleapis.com',
    'https://rxnav.nlm.nih.gov',
    'https://securetoken.googleapis.com',
    'https://www.google.com',
    'https://www.googleapis.com',
    'https://www.recaptcha.net',
  ]);
  assert.equal(observed.web.htmlMetaCspPresent, false);
  assert.equal(observed.web.hostedResponseHeaderCapture, 'not_observed');
});

test('source changes to cleartext, ATS exceptions, and hosted connect-src remain observable', () => {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'parkinsum-platform-egress-'));
  const write = (relativePath, content) => {
    const absolutePath = path.join(fixtureRoot, relativePath);
    mkdirSync(path.dirname(absolutePath), { recursive: true });
    writeFileSync(absolutePath, content);
  };
  try {
    write(
      'android/app/build.gradle.kts',
      'android {\n    defaultConfig {\n        targetSdk = 34\n        usesCleartextTraffic = true\n    }\n}\n',
    );
    write(
      'android/app/src/main/AndroidManifest.xml',
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true" android:networkSecurityConfig="@xml/custom"/></manifest>',
    );
    write('android/app/src/main/res/xml/network_security_config_custom.xml', '<network-security-config/>');
    write(
      'ios/Runner/Info.plist',
      '<plist><dict><key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/><key>NSExceptionDomains</key><dict><key>example.test</key><dict/></dict></dict><key>NSLocalNetworkUsageDescription</key><string>Local model</string></dict></plist>',
    );
    write(
      'ios/Runner.xcodeproj/project.pbxproj',
      'IPHONEOS_DEPLOYMENT_TARGET = 16.0;\nINFOPLIST_KEY_NSAllowsArbitraryLoads = YES;\n',
    );
    write('macos/Runner/Info.plist', '<plist><dict/></plist>');
    write('macos/Runner.xcodeproj/project.pbxproj', 'MACOSX_DEPLOYMENT_TARGET = 13.0;\n');
    write(
      'firebase.json',
      JSON.stringify({
        hosting: {
          headers: [{
            source: '**',
            headers: [{
              key: 'Content-Security-Policy',
              value: "default-src 'none'; connect-src 'self' https://api.example.test",
            }],
          }],
        },
      }),
    );
    write(
      'web/index.html',
      '<html><head><meta http-equiv="Content-Security-Policy" content="default-src none"></head></html>',
    );

    const observed = inspectPlatformNetworkConfiguration(fixtureRoot);
    assert.equal(observed.android.targetSdkExpression, '34');
    assert.deepEqual(observed.android.gradleNetworkOverrides, ['usesCleartextTraffic = true']);
    assert.equal(observed.android.sourceManifests[0].internetPermission, true);
    assert.equal(observed.android.sourceManifests[0].usesCleartextTraffic, 'true');
    assert.equal(observed.android.sourceManifests[0].networkSecurityConfig, '@xml/custom');
    assert.deepEqual(observed.android.networkSecurityConfigFiles, [
      {
        path: 'android/app/src/main/res/xml/network_security_config_custom.xml',
        sha256: createHash('sha256').update('<network-security-config/>').digest('hex'),
      },
    ]);
    assert.equal(observed.apple.ios.atsDictionaryPresent, true);
    assert.equal(observed.apple.ios.allowsArbitraryLoadsPresent, true);
    assert.equal(observed.apple.ios.exceptionDomainsPresent, true);
    assert.equal(observed.apple.ios.localNetworkUsageDescriptionPresent, true);
    const initialAtsDigest = observed.apple.ios.atsDictionarySha256;
    assert.deepEqual(observed.apple.ios.projectNetworkOverrides, [{
      path: 'ios/Runner.xcodeproj/project.pbxproj',
      key: 'NSAllowsArbitraryLoads',
      value: 'YES',
    }]);
    assert.deepEqual(observed.apple.ios.deploymentTargets, ['16.0']);
    assert.deepEqual(observed.web.cspHeaders[0].sources, [
      "'self'",
      'https://api.example.test',
    ]);
    assert.equal(observed.web.htmlMetaCspPresent, true);

    write(
      'android/app/src/main/res/xml/network_security_config_custom.xml',
      '<network-security-config><base-config cleartextTrafficPermitted="false"/></network-security-config>',
    );
    write(
      'ios/Runner/Info.plist',
      '<plist><dict><key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><false/><key>NSExceptionDomains</key><dict><key>example.test</key><dict/></dict></dict><key>NSLocalNetworkUsageDescription</key><string>Local model</string></dict></plist>',
    );
    const changed = inspectPlatformNetworkConfiguration(fixtureRoot);
    assert.notEqual(
      changed.android.networkSecurityConfigFiles[0].sha256,
      observed.android.networkSecurityConfigFiles[0].sha256,
    );
    assert.notEqual(changed.apple.ios.atsDictionarySha256, initialAtsDigest);
  } finally {
    rmSync(fixtureRoot, { recursive: true, force: true });
  }
});
