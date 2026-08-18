import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { resolveReleaseAppCheckConfig } from './release_app_check_config.mjs';

const modulePath = fileURLToPath(
  new URL('./release_app_check_config.mjs', import.meta.url),
);
const appCheckEnvironmentKeys = [
  'PARKINSUM_ENV',
  'PARKINSUM_FIREBASE_APP_CHECK',
  'PARKINSUM_FIREBASE_APP_CHECK_DEBUG',
  'PARKINSUM_RECAPTCHA_SITE_KEY',
  'PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY',
];

function defineMap(config) {
  return Object.fromEntries(
    config.dartDefineArgs.map((argument) => {
      const payload = argument.slice('--dart-define='.length);
      const separator = payload.indexOf('=');
      return [payload.slice(0, separator), payload.slice(separator + 1)];
    }),
  );
}

function cleanEnvironment(overrides = {}) {
  const environment = { ...process.env };
  for (const key of appCheckEnvironmentKeys) delete environment[key];
  return { ...environment, ...overrides };
}

test('stage defaults to live App Check with a v3 key', () => {
  const config = resolveReleaseAppCheckConfig({
    environment: 'stage',
    recaptchaSiteKey: 'stage-v3-key',
  });

  assert.equal(config.enabled, true);
  assert.equal(config.debug, false);
  assert.equal(config.provider, 'recaptcha_v3');
  assert.deepEqual(defineMap(config), {
    PARKINSUM_FIREBASE_APP_CHECK: 'true',
    PARKINSUM_FIREBASE_APP_CHECK_DEBUG: 'false',
    PARKINSUM_RECAPTCHA_SITE_KEY: 'stage-v3-key',
    PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY: '',
  });
});

test('prod accepts the Enterprise provider and emits every required define', () => {
  const config = resolveReleaseAppCheckConfig({
    environment: 'prod',
    recaptchaEnterpriseSiteKey: 'prod-enterprise-key',
  });

  assert.equal(config.provider, 'recaptcha_enterprise');
  assert.equal(config.dartDefineArgs.length, 4);
  assert.equal(
    defineMap(config).PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY,
    'prod-enterprise-key',
  );
});

for (const environment of ['stage', 'prod']) {
  test(`${environment} rejects an explicit App Check opt-out`, () => {
    assert.throws(
      () =>
        resolveReleaseAppCheckConfig({
          environment,
          appCheckEnabled: 'false',
        }),
      /is not allowed/,
    );
  });

  test(`${environment} rejects the debug provider`, () => {
    assert.throws(
      () =>
        resolveReleaseAppCheckConfig({
          environment,
          appCheckDebug: 'true',
        }),
      /DEBUG=true is not allowed/,
    );
  });
}

test('enabled non-debug builds fail closed without either live provider key', () => {
  assert.throws(
    () => resolveReleaseAppCheckConfig({ environment: 'dev' }),
    /requires PARKINSUM_RECAPTCHA_SITE_KEY or PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY/,
  );
});

test('dev may explicitly disable App Check and still emits all defines', () => {
  const config = resolveReleaseAppCheckConfig({
    environment: 'dev',
    appCheckEnabled: 'false',
  });

  assert.equal(config.enabled, false);
  assert.equal(config.provider, 'disabled');
  assert.deepEqual(defineMap(config), {
    PARKINSUM_FIREBASE_APP_CHECK: 'false',
    PARKINSUM_FIREBASE_APP_CHECK_DEBUG: 'false',
    PARKINSUM_RECAPTCHA_SITE_KEY: '',
    PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY: '',
  });
});

test('dev may use the debug provider without a live key', () => {
  const config = resolveReleaseAppCheckConfig({
    environment: 'dev',
    appCheckDebug: 'true',
  });

  assert.equal(config.enabled, true);
  assert.equal(config.debug, true);
  assert.equal(config.provider, 'debug');
});

test('disabled App Check rejects a contradictory debug setting', () => {
  assert.throws(
    () =>
      resolveReleaseAppCheckConfig({
        environment: 'dev',
        appCheckEnabled: 'false',
        appCheckDebug: 'true',
      }),
    /cannot be combined/,
  );
});

test('boolean settings reject ambiguous values', () => {
  assert.throws(
    () =>
      resolveReleaseAppCheckConfig({
        environment: 'dev',
        appCheckEnabled: 'yes',
      }),
    /must be true or false/,
  );
});

test('site keys reject line breaks because CLI output is line-delimited', () => {
  assert.throws(
    () =>
      resolveReleaseAppCheckConfig({
        environment: 'stage',
        recaptchaSiteKey: 'first\nsecond',
      }),
    /single-line value/,
  );
});

test('CLI fails before a stage build when a provider key is absent', () => {
  const result = spawnSync(
    process.execPath,
    [modulePath, '--env', 'stage', '--format', 'lines'],
    {
      cwd: path.dirname(path.dirname(modulePath)),
      env: cleanEnvironment(),
      encoding: 'utf8',
    },
  );

  assert.equal(result.status, 2);
  assert.match(result.stderr, /requires PARKINSUM_RECAPTCHA_SITE_KEY/);
  assert.equal(result.stdout, '');
});

test('CLI emits exactly four build arguments for a valid prod configuration', () => {
  const result = spawnSync(
    process.execPath,
    [modulePath, '--env', 'prod', '--format', 'lines'],
    {
      cwd: path.dirname(path.dirname(modulePath)),
      env: cleanEnvironment({
        PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY: 'prod-enterprise-key',
      }),
      encoding: 'utf8',
    },
  );

  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trimEnd().split('\n');
  assert.equal(lines.length, 4);
  assert.ok(
    lines.includes('--dart-define=PARKINSUM_FIREBASE_APP_CHECK=true'),
  );
  assert.ok(
    lines.includes('--dart-define=PARKINSUM_FIREBASE_APP_CHECK_DEBUG=false'),
  );
  assert.ok(
    lines.includes(
      '--dart-define=PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY=prod-enterprise-key',
    ),
  );
});
