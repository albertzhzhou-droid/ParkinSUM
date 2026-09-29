#!/usr/bin/env node

import { createHash, randomBytes } from 'node:crypto';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const FIXTURE_PATH = 'test/fixtures/smart_r4_launch_preflight.json';
const REQUIRED_SCOPES = Object.freeze([
  'launch/patient',
  'patient/Observation.rs',
]);
const REQUIRED_CAPABILITIES = Object.freeze([
  'launch-standalone',
  'client-public',
  'context-standalone-patient',
  'permission-patient',
  'permission-v2',
]);
const FIXTURE_KEYS = [
  'schemaVersion',
  'fixtureId',
  'fhirVersion',
  'fhirBaseUrl',
  'discoveryUrl',
  'discoveryResponse',
  'clientType',
  'clientId',
  'redirectUri',
  'registeredRedirectUris',
  'launchMode',
  'metadata',
];
const METADATA_KEYS = [
  'authorization_endpoint',
  'token_endpoint',
  'grant_types_supported',
  'response_types_supported',
  'scopes_supported',
  'code_challenge_methods_supported',
  'capabilities',
];

function fail(message) {
  throw new Error(`SMART launch preflight: ${message}`);
}

function exactKeys(value, expected, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(required)) {
    fail(`${label} has missing or unknown fields`);
  }
}

function stringArray(value, label) {
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== 'string')) {
    fail(`${label} must be an array of strings`);
  }
  if (new Set(value).size !== value.length) {
    fail(`${label} must not contain duplicates`);
  }
  return value;
}

function syntheticHttpsUrl(value, label) {
  if (typeof value !== 'string' || value.length > 512) {
    fail(`${label} must be a short URL`);
  }
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    fail(`${label} must be an absolute URL`);
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.username !== '' ||
    parsed.password !== '' ||
    parsed.search !== '' ||
    parsed.hash !== '' ||
    !parsed.hostname.endsWith('.example.org') ||
    parsed.href !== value
  ) {
    fail(`${label} must be a canonical HTTPS URL under example.org`);
  }
  return parsed;
}

function httpsMetadataUrl(value, label) {
  if (typeof value !== 'string' || value.length > 2048) {
    fail(`${label} must be a bounded absolute HTTPS URL`);
  }
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    fail(`${label} must be an absolute URL`);
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.username !== '' ||
    parsed.password !== '' ||
    parsed.hash !== ''
  ) {
    fail(`${label} must use HTTPS without userinfo or a fragment`);
  }
  return parsed;
}

function discoveryStringArray(value, label) {
  const result = stringArray(value, label);
  if (
    result.length > 256 ||
    result.some((entry) => entry.length === 0 || entry.length > 512 || entry.trim() !== entry)
  ) {
    fail(`${label} entries must be non-empty, trimmed, and bounded`);
  }
  return result;
}

/**
 * Validates the modeled HTTP response and consumed SMART 2.2 discovery fields.
 * Unknown metadata properties are ignored for forward compatibility; this
 * preview only consumes an explicit allowlist and never follows discovered URLs.
 */
export function validateSyntheticSmartDiscoveryResponse({
  statusCode,
  contentType,
  body,
}) {
  if (statusCode !== 200) fail('discovery response status must equal 200');
  if (
    typeof contentType !== 'string' ||
    contentType.length > 128 ||
    contentType.split(';', 1)[0].trim().toLowerCase() !== 'application/json'
  ) {
    fail('discovery response content type must be application/json');
  }
  if (typeof body !== 'string' || Buffer.byteLength(body, 'utf8') > 64 * 1024) {
    fail('discovery response body must be a string no larger than 64 KiB');
  }
  let metadata;
  try {
    metadata = JSON.parse(body);
  } catch {
    fail('discovery response body must be valid JSON');
  }
  if (metadata === null || typeof metadata !== 'object' || Array.isArray(metadata)) {
    fail('discovery response body must contain an object');
  }

  httpsMetadataUrl(metadata.token_endpoint, 'token_endpoint');
  const grantTypes = discoveryStringArray(
    metadata.grant_types_supported,
    'grant_types_supported',
  );
  const responseTypes = discoveryStringArray(
    metadata.response_types_supported,
    'response_types_supported',
  );
  const supportedScopes = discoveryStringArray(
    metadata.scopes_supported,
    'scopes_supported',
  );
  const pkceMethods = discoveryStringArray(
    metadata.code_challenge_methods_supported,
    'code_challenge_methods_supported',
  );
  const capabilities = discoveryStringArray(
    metadata.capabilities,
    'capabilities',
  );
  if (!grantTypes.includes('authorization_code')) {
    fail('authorization_code is not supported');
  }
  if (!responseTypes.includes('code')) fail('code response is not supported');
  if (!pkceMethods.includes('S256') || pkceMethods.includes('plain')) {
    fail('server must support S256 and must not advertise plain PKCE');
  }
  for (const capability of REQUIRED_CAPABILITIES) {
    if (!capabilities.includes(capability)) {
      fail(`server does not advertise required capability: ${capability}`);
    }
  }
  for (const scope of REQUIRED_SCOPES) {
    if (!supportedScopes.includes(scope)) {
      fail(`required minimum scope is not supported: ${scope}`);
    }
  }

  const launchSupported = capabilities.includes('launch-ehr') ||
    capabilities.includes('launch-standalone');
  const authorizationEndpoint = metadata.authorization_endpoint === undefined
    ? null
    : httpsMetadataUrl(metadata.authorization_endpoint, 'authorization_endpoint');
  if (launchSupported && authorizationEndpoint === null) {
    fail('authorization_endpoint is required for SMART App Launch');
  }
  for (const [field, label] of [
    ['issuer', 'issuer'],
    ['jwks_uri', 'jwks_uri'],
    ['registration_endpoint', 'registration_endpoint'],
    ['management_endpoint', 'management_endpoint'],
    ['introspection_endpoint', 'introspection_endpoint'],
    ['revocation_endpoint', 'revocation_endpoint'],
    ['user_access_brand_bundle', 'user_access_brand_bundle'],
  ]) {
    if (metadata[field] !== undefined) httpsMetadataUrl(metadata[field], label);
  }
  const openIdConnectAdvertised = capabilities.includes('sso-openid-connect');
  if (openIdConnectAdvertised && metadata.issuer === undefined) {
    fail('issuer is required for sso-openid-connect');
  }
  if (openIdConnectAdvertised && metadata.jwks_uri === undefined) {
    fail('jwks_uri is required for sso-openid-connect');
  }

  return {
    status200Accepted: true,
    applicationJsonAccepted: true,
    requiredCoreMetadataPresent: true,
    authorizationEndpointPresentForLaunch: authorizationEndpoint !== null,
    requiredCapabilitiesPresent: true,
    minimumScopesPresent: true,
    s256RequiredAndPlainExcluded: true,
    openIdConnectMetadataState: openIdConnectAdvertised
      ? 'required_and_validated'
      : 'not_advertised',
    fullDiscoveredEndpointUrlsOmitted: true,
  };
}

export function validateSmartLaunchFixture(fixture) {
  exactKeys(fixture, FIXTURE_KEYS, 'fixture');
  if (fixture.schemaVersion !== 3) fail('schemaVersion must equal 3');
  if (fixture.fixtureId !== 'synthetic_smart_r4_standalone_launch') {
    fail('fixtureId is not the pinned synthetic fixture');
  }
  if (fixture.fhirVersion !== '4.0.1') fail('FHIR version must be 4.0.1');
  if (fixture.clientType !== 'public') fail('only a public client is supported');
  if (fixture.launchMode !== 'standalone') {
    fail('only a standalone launch preview is supported');
  }
  if (
    typeof fixture.clientId !== 'string' ||
    !/^[A-Za-z0-9._-]{1,128}$/.test(fixture.clientId)
  ) {
    fail('clientId must be a bounded public-client identifier');
  }

  const fhirBase = syntheticHttpsUrl(fixture.fhirBaseUrl, 'fhirBaseUrl');
  if (fhirBase.pathname === '/' || fhirBase.pathname.endsWith('/')) {
    fail('fhirBaseUrl must be a canonical FHIR base with no trailing slash');
  }
  const discoveryDocument = syntheticHttpsUrl(
    fixture.discoveryUrl,
    'discoveryUrl',
  );
  const expectedDiscoveryUrl =
    `${fhirBase.href}/.well-known/smart-configuration`;
  if (discoveryDocument.href !== expectedDiscoveryUrl) {
    fail('discoveryUrl must append the SMART well-known path to fhirBaseUrl');
  }
  exactKeys(
    fixture.discoveryResponse,
    ['statusCode', 'contentType'],
    'discoveryResponse',
  );
  const redirect = syntheticHttpsUrl(fixture.redirectUri, 'redirectUri');
  if (redirect.pathname === '/') fail('redirectUri must include a callback path');
  const registeredRedirectUris = stringArray(
    fixture.registeredRedirectUris,
    'registeredRedirectUris',
  );
  if (
    registeredRedirectUris.length !== 1 ||
    registeredRedirectUris[0] !== fixture.redirectUri
  ) {
    fail('redirectUri must exactly match the single registered callback');
  }

  exactKeys(fixture.metadata, METADATA_KEYS, 'metadata');
  const discoveryResponseContract = validateSyntheticSmartDiscoveryResponse({
    statusCode: fixture.discoveryResponse.statusCode,
    contentType: fixture.discoveryResponse.contentType,
    body: JSON.stringify(fixture.metadata),
  });
  const authorizationEndpoint = syntheticHttpsUrl(
    fixture.metadata.authorization_endpoint,
    'authorization_endpoint',
  );
  syntheticHttpsUrl(fixture.metadata.token_endpoint, 'token_endpoint');
  return {
    authorizationEndpoint,
    discoveryDocument,
    discoveryResponseContract,
    fhirBase,
    redirect,
  };
}

export function createPkcePair() {
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier, 'ascii')
    .digest('base64url');
  return { verifier, challenge, method: 'S256' };
}

export function validateSyntheticSmartAuthorizationResponse({
  callbackUrl,
  redirectUri,
  registeredRedirectUris,
  expectedState,
}) {
  if (
    !Array.isArray(registeredRedirectUris) ||
    registeredRedirectUris.length !== 1 ||
    registeredRedirectUris[0] !== redirectUri
  ) {
    fail('callback must use the exact single registered redirect URI');
  }
  const redirect = syntheticHttpsUrl(redirectUri, 'redirectUri');
  if (redirect.pathname === '/') fail('redirectUri must include a callback path');
  if (typeof expectedState !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(expectedState)) {
    fail('expected state must be the transient 256-bit base64url value');
  }
  if (typeof callbackUrl !== 'string') fail('callback URL must be a string');

  let callback;
  try {
    callback = new URL(callbackUrl);
  } catch {
    fail('callback URL must be absolute');
  }
  if (
    callback.protocol !== 'https:' ||
    callback.username !== '' ||
    callback.password !== '' ||
    callback.origin !== redirect.origin ||
    callback.pathname !== redirect.pathname ||
    callbackUrl.includes('#')
  ) {
    fail('callback URL must return to the exact registered callback');
  }

  const parameters = callback.searchParams;
  for (const name of new Set(parameters.keys())) {
    if (parameters.getAll(name).length !== 1) {
      fail('callback parameters must not be repeated');
    }
  }
  const states = parameters.getAll('state');
  if (states.length !== 1 || states[0] !== expectedState) {
    fail('callback state does not match the transient launch state');
  }

  const codes = parameters.getAll('code');
  const errors = parameters.getAll('error');
  if ((codes.length === 1) === (errors.length === 1)) {
    fail('callback must contain exactly one of code or error');
  }
  if (codes.length === 1) {
    if (!codes[0] || parameters.has('error_description') || parameters.has('error_uri')) {
      fail('successful callback has an invalid code response shape');
    }
    return {
      callbackBaseMatched: true,
      stateMatched: true,
      responseType: 'code',
      authorizationCodeValueOmitted: true,
      errorDetailsOmitted: true,
    };
  }

  if (!/^[A-Za-z0-9._-]{1,128}$/.test(errors[0])) {
    fail('error response must contain a bounded OAuth error code');
  }
  return {
    callbackBaseMatched: true,
    stateMatched: true,
    responseType: 'error',
    authorizationCodeValueOmitted: true,
    errorDetailsOmitted: true,
  };
}

function validateSyntheticCallbackExamples(fixture, state) {
  const codeCallback = new URL(fixture.redirectUri);
  codeCallback.searchParams.set('code', 'synthetic-only-never-exchanged');
  codeCallback.searchParams.set('state', state);
  const codeResult = validateSyntheticSmartAuthorizationResponse({
    callbackUrl: codeCallback.href,
    redirectUri: fixture.redirectUri,
    registeredRedirectUris: fixture.registeredRedirectUris,
    expectedState: state,
  });

  const deniedCallback = new URL(fixture.redirectUri);
  deniedCallback.searchParams.set('error', 'access_denied');
  deniedCallback.searchParams.set('state', state);
  const deniedResult = validateSyntheticSmartAuthorizationResponse({
    callbackUrl: deniedCallback.href,
    redirectUri: fixture.redirectUri,
    registeredRedirectUris: fixture.registeredRedirectUris,
    expectedState: state,
  });

  function requireRejection(callbackUrl, label) {
    try {
      validateSyntheticSmartAuthorizationResponse({
        callbackUrl,
        redirectUri: fixture.redirectUri,
        registeredRedirectUris: fixture.registeredRedirectUris,
        expectedState: state,
      });
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('SMART launch preflight:')) {
        return true;
      }
      throw error;
    }
    fail(`${label} callback was unexpectedly accepted`);
  }

  const mismatchedState = new URL(fixture.redirectUri);
  mismatchedState.searchParams.set('code', 'synthetic-only-never-exchanged');
  mismatchedState.searchParams.set('state', 'synthetic-wrong-state');
  const mismatchedStateRejected = requireRejection(
    mismatchedState.href,
    'mismatched-state',
  );

  const repeatedState = new URL(fixture.redirectUri);
  repeatedState.searchParams.set('code', 'synthetic-only-never-exchanged');
  repeatedState.searchParams.append('state', state);
  repeatedState.searchParams.append('state', state);
  const repeatedStateRejected = requireRejection(
    repeatedState.href,
    'repeated-state',
  );

  const ambiguous = new URL(fixture.redirectUri);
  ambiguous.searchParams.set('code', 'synthetic-only-never-exchanged');
  ambiguous.searchParams.set('error', 'access_denied');
  ambiguous.searchParams.set('state', state);
  const ambiguousResponseRejected = requireRejection(
    ambiguous.href,
    'ambiguous-code-error',
  );

  const foreignCallback = new URL(fixture.redirectUri);
  foreignCallback.pathname = '/unregistered/callback';
  foreignCallback.searchParams.set('code', 'synthetic-only-never-exchanged');
  foreignCallback.searchParams.set('state', state);
  const foreignCallbackRejected = requireRejection(
    foreignCallback.href,
    'unregistered-callback',
  );

  const emptyResponse = new URL(fixture.redirectUri);
  emptyResponse.searchParams.set('state', state);
  const emptyResponseRejected = requireRejection(
    emptyResponse.href,
    'empty-response',
  );

  return {
    codeResult,
    deniedResult,
    mismatchedStateRejected,
    repeatedStateRejected,
    ambiguousResponseRejected,
    foreignCallbackRejected,
    emptyResponseRejected,
  };
}

export function buildSmartLaunchPreflightReport(fixture) {
  const { authorizationEndpoint, discoveryDocument, discoveryResponseContract } =
    validateSmartLaunchFixture(fixture);
  const { verifier, challenge } = createPkcePair();
  const state = randomBytes(32).toString('base64url');
  if (state.length !== 43) fail('generated state length is invalid');
  const parameters = new URLSearchParams();
  parameters.set('response_type', 'code');
  parameters.set('client_id', fixture.clientId);
  parameters.set('redirect_uri', fixture.redirectUri);
  parameters.set('scope', REQUIRED_SCOPES.join(' '));
  parameters.set('state', state);
  parameters.set('aud', fixture.fhirBaseUrl);
  parameters.set('code_challenge', challenge);
  parameters.set('code_challenge_method', 'S256');

  // Construct and validate the request in memory, but never return, open, or
  // persist it. The verifier is deliberately discarded: this is not a usable
  // OAuth launch or token-exchange implementation.
  const authorizationUrl = new URL(authorizationEndpoint.href);
  authorizationUrl.search = parameters.toString();
  if (authorizationUrl.searchParams.size !== 8) {
    fail('authorization request parameter count drifted');
  }
  if (authorizationUrl.searchParams.get('aud') !== fixture.fhirBaseUrl) {
    fail('audience does not exactly match the FHIR base');
  }
  if (authorizationUrl.searchParams.get('scope') !== REQUIRED_SCOPES.join(' ')) {
    fail('authorization request scope drifted');
  }
  if (authorizationUrl.searchParams.get('code_challenge_method') !== 'S256') {
    fail('authorization request does not use S256');
  }
  if (verifier.length < 43 || verifier.length > 128) {
    fail('generated PKCE verifier length is invalid');
  }
  const callbackChecks = validateSyntheticCallbackExamples(fixture, state);
  const { codeResult, deniedResult } = callbackChecks;

  const canonicalFixture = JSON.stringify(fixture);
  const fixtureDigest = createHash('sha256')
    .update(canonicalFixture, 'utf8')
    .digest('hex');
  return {
    schemaVersion: 4,
    fixtureId: fixture.fixtureId,
    fixtureDigest,
    result: 'pass',
    mode: 'synthetic_standalone_request_and_callback_contract_preview_only',
    fhirVersion: fixture.fhirVersion,
    discoveryDocumentUrl: discoveryDocument.href,
    discoveryMetadataShapeValidated: true,
    discoveryResponseContract,
    authorizationEndpointHost: authorizationEndpoint.hostname,
    authorizationRequest: {
      responseType: 'code',
      clientType: 'public',
      requestedScopes: [...REQUIRED_SCOPES],
      patientContextRequested: true,
      resourceAccess: 'patient/Observation.rs',
      pkceMethod: 'S256',
      stateEntropyBits: 256,
      redirectUriRegisteredExactly: true,
      clientSecretUsed: false,
      broadOrWriteScopesRequested: false,
      parameterNames: [...parameters.keys()],
      generatedValuesOmitted: [
        'state',
        'code_challenge',
        'code_verifier',
      ],
    },
    authorizationResponse: {
      codeResponseValidated: codeResult.responseType === 'code',
      denialResponseValidated: deniedResult.responseType === 'error',
      callbackBaseMatchedRegisteredExactly:
        codeResult.callbackBaseMatched && deniedResult.callbackBaseMatched,
      stateEchoMatchedExactly: codeResult.stateMatched && deniedResult.stateMatched,
      mismatchedStateRejected: callbackChecks.mismatchedStateRejected,
      repeatedStateRejected: callbackChecks.repeatedStateRejected,
      ambiguousCodeErrorRejected: callbackChecks.ambiguousResponseRejected,
      unregisteredCallbackRejected: callbackChecks.foreignCallbackRejected,
      emptyResponseRejected: callbackChecks.emptyResponseRejected,
      authorizationCodeValueOmitted: codeResult.authorizationCodeValueOmitted,
      errorDetailsOmitted: deniedResult.errorDetailsOmitted,
    },
    activity: {
      discoveryFetches: 0,
      networkRequests: 0,
      authorizationNavigation: 0,
      callbackHandling: 0,
      syntheticAuthorizationResponseChecks: 7,
      tokenExchange: 0,
      fhirReads: 0,
      fhirWrites: 0,
      persistedArtifacts: 0,
    },
    boundary: [
      'fixed synthetic example.org fixture only',
      'no discovery fetch or external server interaction',
      'only in-memory synthetic code and denial callbacks are parsed',
      'no real authorization code, callback handling, token exchange, or FHIR access',
      'no EHR write-back, clinical rule execution, or interoperability certification',
    ],
  };
}

function main() {
  const fixture = JSON.parse(fs.readFileSync(FIXTURE_PATH, 'utf8'));
  const report = buildSmartLaunchPreflightReport(fixture);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
