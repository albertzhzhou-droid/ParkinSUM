import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  evaluateAttestation,
  hostingProfiles,
  responseHeaders,
} from './run_wasm_hosting_attestation.mjs';

function resource(profile, resourcePath = '/main.dart.wasm') {
  return {
    path: resourcePath,
    status: 200,
    headers: responseHeaders(profile, resourcePath),
  };
}

function result(profile, overrides = {}) {
  return {
    id: profile.id,
    expected: {
      coop: profile.coop,
      coep: profile.coep,
      crossOriginIsolated: profile.expectedIsolation,
    },
    resourceAttestations: [
      resource(profile),
      resource(profile, '/canvaskit/skwasm.wasm'),
    ],
    runtime: {
      appReady: true,
      errorSurface: false,
      consoleErrorCount: 0,
      crossOriginIsolated: profile.expectedIsolation,
      sharedArrayBufferAvailable: profile.expectedIsolation,
      mainWasmRequested: true,
      skwasmRequested: true,
      jsFallbackRequested: false,
      crossOriginEngineResources: [],
      ...overrides,
    },
  };
}

function report() {
  return {
    flutterBuildConfig: { useLocalCanvasKit: true },
    flutterBuilds: [
      { compileTarget: 'dart2wasm', renderer: 'skwasm' },
      { compileTarget: 'dart2js', renderer: 'canvaskit' },
    ],
    results: hostingProfiles.map((profile) => result(profile)),
  };
}

test('complete controlled comparison passes', () => {
  assert.deepEqual(evaluateAttestation(report()), []);
});

test('isolated profiles fail without isolation or SharedArrayBuffer', () => {
  const mutated = report();
  mutated.results[1].runtime.crossOriginIsolated = false;
  mutated.results[1].runtime.sharedArrayBufferAvailable = false;
  const failures = evaluateAttestation(mutated);
  assert.ok(failures.some((item) => item.includes('crossOriginIsolated')));
  assert.ok(failures.some((item) => item.includes('SharedArrayBuffer')));
});

test('header drift and invalid Wasm content type fail closed', () => {
  const mutated = report();
  const target = mutated.results[2].resourceAttestations[0];
  delete target.headers['cross-origin-embedder-policy'];
  target.headers['content-type'] = 'application/octet-stream';
  const failures = evaluateAttestation(mutated);
  assert.ok(failures.some((item) => item.includes('headers drifted')));
  assert.ok(failures.some((item) => item.includes('invalid Wasm content type')));
});

test('Wasm resource loss, JS fallback, and app failure stay red', () => {
  const mutated = report();
  Object.assign(mutated.results[1].runtime, {
    appReady: false,
    errorSurface: true,
    consoleErrorCount: 1,
    mainWasmRequested: false,
    jsFallbackRequested: true,
  });
  const failures = evaluateAttestation(mutated);
  assert.ok(failures.some((item) => item.includes('did not become ready')));
  assert.ok(failures.some((item) => item.includes('Error/Retry')));
  assert.ok(failures.some((item) => item.includes('console contains errors')));
  assert.ok(failures.some((item) => item.includes('dart2wasm/skwasm path')));
  assert.ok(failures.some((item) => item.includes('dart2js fallback')));
});

test('cross-origin engine resources and CDN build mode fail closed', () => {
  const mutated = report();
  mutated.flutterBuildConfig.useLocalCanvasKit = false;
  mutated.results[0].runtime.crossOriginEngineResources = [
    'https://www.gstatic.com/flutter-canvaskit/revision/skwasm.wasm',
  ];
  const failures = evaluateAttestation(mutated);
  assert.ok(failures.some((item) => item.includes('same-origin hosting')));
  assert.ok(failures.some((item) => item.includes('fetched cross-origin')));
});

test('missing build candidate or matrix profile fails closed', () => {
  const mutated = report();
  mutated.flutterBuilds.shift();
  mutated.results.pop();
  const failures = evaluateAttestation(mutated);
  assert.ok(failures.some((item) => item.includes('build candidate is missing')));
  assert.ok(failures.some((item) => item.includes('missing profile')));
});

test('cache contract keeps entry and service worker revalidatable', () => {
  const profile = hostingProfiles[1];
  assert.equal(
    responseHeaders(profile, '/')['cache-control'],
    'no-store, max-age=0',
  );
  assert.match(
    responseHeaders(profile, '/flutter_service_worker.js')['cache-control'],
    /must-revalidate/,
  );
  assert.match(
    responseHeaders(profile, '/main.dart.wasm')['cache-control'],
    /immutable/,
  );
});

test('database factories select the Web implementation for dart2wasm', () => {
  for (const file of [
    'lib/core/db/app_database_factory.dart',
    'lib/core/db/cdss_database_factory.dart',
  ]) {
    const source = fs.readFileSync(file, 'utf8');
    assert.match(source, /dart\.library\.js_interop/);
    assert.doesNotMatch(source, /dart\.library\.html/);
  }
});

test('portable export uses the Wasm-compatible Web interop surface', () => {
  const factory = fs.readFileSync(
    'lib/core/services/portable_data_export_sink.dart',
    'utf8',
  );
  const implementation = fs.readFileSync(
    'lib/core/services/portable_data_export_sink_web.dart',
    'utf8',
  );
  assert.match(factory, /dart\.library\.js_interop/);
  assert.doesNotMatch(factory, /dart\.library\.html/);
  assert.match(implementation, /dart:js_interop/);
  assert.match(implementation, /package:web\/web\.dart/);
  assert.doesNotMatch(implementation, /dart:html/);
});
