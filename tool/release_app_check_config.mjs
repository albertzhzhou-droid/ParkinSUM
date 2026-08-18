#!/usr/bin/env node

import path from 'node:path';
import { pathToFileURL } from 'node:url';

const dartDefinePrefix = '--dart-define=';
const protectedEnvironments = new Set(['stage', 'prod']);
const supportedEnvironments = new Set(['dev', ...protectedEnvironments]);

/**
 * Resolve the App Check settings used by the release build.
 *
 * App Check is enabled by default for every release environment. Development
 * builds may explicitly disable it; stage and production builds may not. A
 * non-debug build must identify a live reCAPTCHA provider, and the debug
 * provider is development-only.
 */
export function resolveReleaseAppCheckConfig({
  environment,
  appCheckEnabled,
  appCheckDebug,
  recaptchaSiteKey,
  recaptchaEnterpriseSiteKey,
}) {
  const normalizedEnvironment = normalizeEnvironment(environment);
  const enabled = parseBoolean(appCheckEnabled, {
    name: 'PARKINSUM_FIREBASE_APP_CHECK',
    defaultValue: true,
  });
  const debug = parseBoolean(appCheckDebug, {
    name: 'PARKINSUM_FIREBASE_APP_CHECK_DEBUG',
    defaultValue: false,
  });
  const siteKey = normalizeSingleLine(
    recaptchaSiteKey,
    'PARKINSUM_RECAPTCHA_SITE_KEY',
  );
  const enterpriseSiteKey = normalizeSingleLine(
    recaptchaEnterpriseSiteKey,
    'PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY',
  );

  if (protectedEnvironments.has(normalizedEnvironment) && !enabled) {
    throw new Error(
      `PARKINSUM_FIREBASE_APP_CHECK=false is not allowed for ${normalizedEnvironment} releases.`,
    );
  }
  if (protectedEnvironments.has(normalizedEnvironment) && debug) {
    throw new Error(
      `PARKINSUM_FIREBASE_APP_CHECK_DEBUG=true is not allowed for ${normalizedEnvironment} releases.`,
    );
  }
  if (!enabled && debug) {
    throw new Error(
      'PARKINSUM_FIREBASE_APP_CHECK_DEBUG=true cannot be combined with PARKINSUM_FIREBASE_APP_CHECK=false.',
    );
  }
  if (
    enabled &&
    !debug &&
    siteKey.length === 0 &&
    enterpriseSiteKey.length === 0
  ) {
    throw new Error(
      'An enabled non-debug App Check release requires PARKINSUM_RECAPTCHA_SITE_KEY or PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY.',
    );
  }

  const provider = !enabled
    ? 'disabled'
    : debug
      ? 'debug'
      : enterpriseSiteKey.length > 0
        ? 'recaptcha_enterprise'
        : 'recaptcha_v3';
  const dartDefineArgs = Object.freeze([
    `${dartDefinePrefix}PARKINSUM_FIREBASE_APP_CHECK=${enabled}`,
    `${dartDefinePrefix}PARKINSUM_FIREBASE_APP_CHECK_DEBUG=${debug}`,
    `${dartDefinePrefix}PARKINSUM_RECAPTCHA_SITE_KEY=${siteKey}`,
    `${dartDefinePrefix}PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY=${enterpriseSiteKey}`,
  ]);

  return Object.freeze({
    environment: normalizedEnvironment,
    enabled,
    debug,
    provider,
    dartDefineArgs,
  });
}

function normalizeEnvironment(value) {
  const environment = String(value ?? '').trim();
  if (!supportedEnvironments.has(environment)) {
    throw new Error(
      `PARKINSUM_ENV must be dev, stage, or prod. Got: ${environment || '<empty>'}.`,
    );
  }
  return environment;
}

function parseBoolean(value, { name, defaultValue }) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized.length === 0) return defaultValue;
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;
  throw new Error(`${name} must be true or false.`);
}

function normalizeSingleLine(value, name) {
  const normalized = String(value ?? '').trim();
  if (/[\r\n\0]/.test(normalized)) {
    throw new Error(`${name} must be a single-line value.`);
  }
  return normalized;
}

function parseCliArgs(argv) {
  const parsed = {
    environment: process.env.PARKINSUM_ENV ?? 'prod',
    format: 'lines',
  };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    const value = argv[index + 1];
    if (token === '--env' || token === '--format') {
      if (value == null || value.startsWith('--')) {
        throw new Error(`${token} requires a value.`);
      }
      if (token === '--env') parsed.environment = value;
      if (token === '--format') parsed.format = value;
      index += 1;
      continue;
    }
    throw new Error(`Unknown option: ${token}`);
  }
  if (parsed.format !== 'lines') {
    throw new Error(`Unsupported output format: ${parsed.format}`);
  }
  return parsed;
}

function runCli() {
  try {
    const args = parseCliArgs(process.argv.slice(2));
    const config = resolveReleaseAppCheckConfig({
      environment: args.environment,
      appCheckEnabled: process.env.PARKINSUM_FIREBASE_APP_CHECK,
      appCheckDebug: process.env.PARKINSUM_FIREBASE_APP_CHECK_DEBUG,
      recaptchaSiteKey: process.env.PARKINSUM_RECAPTCHA_SITE_KEY,
      recaptchaEnterpriseSiteKey:
        process.env.PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY,
    });
    process.stdout.write(`${config.dartDefineArgs.join('\n')}\n`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`App Check release configuration error: ${message}`);
    process.exitCode = 2;
  }
}

const isMain =
  process.argv[1] != null &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;
if (isMain) runCli();
