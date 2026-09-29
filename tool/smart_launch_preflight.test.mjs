import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildSmartLaunchPreflightReport,
  createPkcePair,
  validateSyntheticSmartDiscoveryResponse,
  validateSyntheticSmartAuthorizationResponse,
  validateSmartLaunchFixture,
} from './smart_launch_preflight.mjs';

const fixture = JSON.parse(
  fs.readFileSync('test/fixtures/smart_r4_launch_preflight.json', 'utf8'),
);

function mutate(mutator) {
  const copy = structuredClone(fixture);
  mutator(copy);
  return copy;
}

const syntheticState = 's'.repeat(43);

function syntheticCallback(parameters) {
  const url = new URL(fixture.redirectUri);
  for (const [name, value] of parameters) url.searchParams.append(name, value);
  return url.href;
}

function validateCallback(parameters, overrides = {}) {
  return validateSyntheticSmartAuthorizationResponse({
    callbackUrl: syntheticCallback(parameters),
    redirectUri: fixture.redirectUri,
    registeredRedirectUris: fixture.registeredRedirectUris,
    expectedState: syntheticState,
    ...overrides,
  });
}

test('synthetic SMART R4 request and callback contract stays read-only and minimum-scope', () => {
  const report = buildSmartLaunchPreflightReport(fixture);
  assert.equal(report.schemaVersion, 4);
  assert.equal(report.result, 'pass');
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(
    report.discoveryDocumentUrl,
    'https://ehr.example.org/fhir/r4/.well-known/smart-configuration',
  );
  assert.equal(report.discoveryMetadataShapeValidated, true);
  assert.deepEqual(report.discoveryResponseContract, {
    status200Accepted: true,
    applicationJsonAccepted: true,
    requiredCoreMetadataPresent: true,
    authorizationEndpointPresentForLaunch: true,
    requiredCapabilitiesPresent: true,
    minimumScopesPresent: true,
    s256RequiredAndPlainExcluded: true,
    openIdConnectMetadataState: 'not_advertised',
    fullDiscoveredEndpointUrlsOmitted: true,
  });
  assert.equal(report.mode, 'synthetic_standalone_request_and_callback_contract_preview_only');
  assert.equal(report.authorizationRequest.responseType, 'code');
  assert.equal(report.authorizationRequest.clientType, 'public');
  assert.deepEqual(report.authorizationRequest.requestedScopes, [
    'launch/patient',
    'patient/Observation.rs',
  ]);
  assert.equal(report.authorizationRequest.pkceMethod, 'S256');
  assert.equal(report.authorizationRequest.stateEntropyBits, 256);
  assert.equal(report.authorizationRequest.redirectUriRegisteredExactly, true);
  assert.equal(report.authorizationRequest.clientSecretUsed, false);
  assert.equal(report.authorizationRequest.broadOrWriteScopesRequested, false);
  assert.deepEqual(report.authorizationRequest.parameterNames, [
    'response_type',
    'client_id',
    'redirect_uri',
    'scope',
    'state',
    'aud',
    'code_challenge',
    'code_challenge_method',
  ]);
  assert.deepEqual(report.authorizationRequest.generatedValuesOmitted, [
    'state',
    'code_challenge',
    'code_verifier',
  ]);
  assert.deepEqual(report.authorizationResponse, {
    codeResponseValidated: true,
    denialResponseValidated: true,
    callbackBaseMatchedRegisteredExactly: true,
    stateEchoMatchedExactly: true,
    mismatchedStateRejected: true,
    repeatedStateRejected: true,
    ambiguousCodeErrorRejected: true,
    unregisteredCallbackRejected: true,
    emptyResponseRejected: true,
    authorizationCodeValueOmitted: true,
    errorDetailsOmitted: true,
  });
  assert.deepEqual(report.activity, {
    discoveryFetches: 0,
    networkRequests: 0,
    authorizationNavigation: 0,
    callbackHandling: 0,
    syntheticAuthorizationResponseChecks: 7,
    tokenExchange: 0,
    fhirReads: 0,
    fhirWrites: 0,
    persistedArtifacts: 0,
  });
  assert.equal(JSON.stringify(report).includes('code_verifier'), true);
  assert.equal(JSON.stringify(report).includes(fixture.clientId), false);
  assert.equal(JSON.stringify(report).includes('access_token'), false);
  assert.equal(JSON.stringify(report).includes('refresh_token'), false);
  assert.equal(JSON.stringify(report).includes('Patient/'), false);
  assert.equal(JSON.stringify(report).includes('synthetic-only-never-exchanged'), false);
  assert.equal(JSON.stringify(report).includes('synthetic-wrong-state'), false);
});

test('SMART discovery response accepts JSON media parameters and ignores unknown extensions', () => {
  const metadata = structuredClone(fixture.metadata);
  metadata['https://vendor.example.org/metadata'] = { feature: 'future' };
  const result = validateSyntheticSmartDiscoveryResponse({
    statusCode: fixture.discoveryResponse.statusCode,
    contentType: 'Application/JSON; charset=UTF-8',
    body: JSON.stringify(metadata),
  });
  assert.deepEqual(result, {
    status200Accepted: true,
    applicationJsonAccepted: true,
    requiredCoreMetadataPresent: true,
    authorizationEndpointPresentForLaunch: true,
    requiredCapabilitiesPresent: true,
    minimumScopesPresent: true,
    s256RequiredAndPlainExcluded: true,
    openIdConnectMetadataState: 'not_advertised',
    fullDiscoveredEndpointUrlsOmitted: true,
  });
  assert.equal(JSON.stringify(result).includes('auth.example.org'), false);
  assert.equal(JSON.stringify(result).includes('future'), false);
});

test('SMART discovery response rejects wrong HTTP envelope and oversized or malformed bodies', () => {
  const valid = {
    statusCode: 200,
    contentType: 'application/json',
    body: JSON.stringify(fixture.metadata),
  };
  assert.throws(() => validateSyntheticSmartDiscoveryResponse({
    ...valid,
    statusCode: 302,
  }), /status must equal 200/);
  assert.throws(() => validateSyntheticSmartDiscoveryResponse({
    ...valid,
    contentType: 'text/html',
  }), /content type must be application\/json/);
  assert.throws(() => validateSyntheticSmartDiscoveryResponse({
    ...valid,
    body: '{broken json',
  }), /valid JSON/);
  assert.throws(() => validateSyntheticSmartDiscoveryResponse({
    ...valid,
    body: JSON.stringify({ ...fixture.metadata, extension: 'x'.repeat(66_000) }),
  }), /no larger than 64 KiB/);
  assert.throws(() => validateSyntheticSmartDiscoveryResponse({
    ...valid,
    body: '[]',
  }), /must contain an object/);
});

test('SMART discovery response enforces required capabilities, scopes, and endpoint support', () => {
  const mutations = [
    (metadata) => { delete metadata.token_endpoint; },
    (metadata) => { delete metadata.grant_types_supported; },
    (metadata) => { delete metadata.capabilities; },
    (metadata) => { delete metadata.code_challenge_methods_supported; },
    (metadata) => { metadata.response_types_supported = ['token']; },
    (metadata) => { metadata.scopes_supported = ['launch/patient']; },
    (metadata) => { metadata.code_challenge_methods_supported.push('plain'); },
    (metadata) => { delete metadata.authorization_endpoint; },
    (metadata) => { metadata.authorization_endpoint = 'http://auth.example.org/authorize'; },
    (metadata) => { metadata.token_endpoint = 'https://user@auth.example.org/token'; },
  ];
  for (const mutateMetadata of mutations) {
    const metadata = structuredClone(fixture.metadata);
    mutateMetadata(metadata);
    assert.throws(() => validateSyntheticSmartDiscoveryResponse({
      statusCode: 200,
      contentType: 'application/json',
      body: JSON.stringify(metadata),
    }));
  }
});

test('SMART discovery requires issuer and JWKS only when OpenID Connect is advertised', () => {
  const metadata = structuredClone(fixture.metadata);
  metadata.capabilities.push('sso-openid-connect');
  metadata.issuer = 'https://auth.example.org';
  metadata.jwks_uri = 'https://auth.example.org/.well-known/jwks.json';
  const response = (value) => validateSyntheticSmartDiscoveryResponse({
    statusCode: 200,
    contentType: 'application/json',
    body: JSON.stringify(value),
  });
  assert.deepEqual(response(metadata), {
    status200Accepted: true,
    applicationJsonAccepted: true,
    requiredCoreMetadataPresent: true,
    authorizationEndpointPresentForLaunch: true,
    requiredCapabilitiesPresent: true,
    minimumScopesPresent: true,
    s256RequiredAndPlainExcluded: true,
    openIdConnectMetadataState: 'required_and_validated',
    fullDiscoveredEndpointUrlsOmitted: true,
  });
  const missingIssuer = structuredClone(metadata);
  delete missingIssuer.issuer;
  assert.throws(() => response(missingIssuer), /issuer is required/);
  const missingJwks = structuredClone(metadata);
  delete missingJwks.jwks_uri;
  assert.throws(() => response(missingJwks), /jwks_uri is required/);
  const invalidIssuer = structuredClone(metadata);
  invalidIssuer.issuer = 'http://auth.example.org';
  assert.throws(() => response(invalidIssuer), /must use HTTPS/);
});

test('synthetic authorization code response requires exact state and registered callback', () => {
  const result = validateCallback([
    ['code', 'synthetic-code-that-is-never-exchanged'],
    ['state', syntheticState],
    ['future_extension', 'ignored-by-this-preview'],
  ]);
  assert.deepEqual(result, {
    callbackBaseMatched: true,
    stateMatched: true,
    responseType: 'code',
    authorizationCodeValueOmitted: true,
    errorDetailsOmitted: true,
  });
  assert.equal(JSON.stringify(result).includes(syntheticState), false);
  assert.equal(JSON.stringify(result).includes('synthetic-code-that-is-never-exchanged'), false);
});

test('synthetic denial response is recognized without returning its details', () => {
  const result = validateCallback([
    ['error', 'access_denied'],
    ['error_description', 'synthetic private explanation'],
    ['error_uri', 'https://auth.example.org/error'],
    ['state', syntheticState],
  ]);
  assert.deepEqual(result, {
    callbackBaseMatched: true,
    stateMatched: true,
    responseType: 'error',
    authorizationCodeValueOmitted: true,
    errorDetailsOmitted: true,
  });
  assert.equal(JSON.stringify(result).includes('access_denied'), false);
  assert.equal(JSON.stringify(result).includes('synthetic private explanation'), false);
});

test('callback rejects missing, mismatched, or repeated state values', () => {
  assert.throws(() => validateCallback([
    ['code', 'synthetic-code'],
  ]), /state does not match/);
  assert.throws(() => validateCallback([
    ['code', 'synthetic-code'],
    ['state', 'different-state'],
  ]), /state does not match/);
  assert.throws(() => validateCallback([
    ['code', 'synthetic-code'],
    ['state', syntheticState],
    ['state', syntheticState],
  ]), /must not be repeated/);
  assert.throws(() => validateCallback([
    ['code', 'synthetic-code'],
    ['state', syntheticState],
  ], { expectedState: 'short-state' }), /256-bit base64url/);
});

test('callback rejects ambiguous code/error response shapes', () => {
  const cases = [
    [],
    [['code', 'synthetic-code'], ['error', 'access_denied']],
    [['code', '']],
    [['error', '']],
    [['error', 'not an oauth error']],
    [['code', 'synthetic-code'], ['error_description', 'orphaned']],
  ];
  for (const fields of cases) {
    assert.throws(() => validateCallback([
      ...fields,
      ['state', syntheticState],
    ]));
  }
});

test('callback rejects open redirects and duplicate query parameters', () => {
  const validParameters = [
    ['code', 'synthetic-code'],
    ['state', syntheticState],
  ];
  assert.throws(() => validateCallback(validParameters, {
    registeredRedirectUris: ['https://app.example.org/other'],
  }), /exact single registered redirect URI/);
  for (const callbackUrl of [
    'https://other.example.org/smart/callback?code=x&state=state',
    'https://app.example.org/other?code=x&state=state',
    'http://app.example.org/smart/callback?code=x&state=state',
    `${fixture.redirectUri}?code=x&state=state#fragment`,
  ]) {
    assert.throws(() => validateSyntheticSmartAuthorizationResponse({
      callbackUrl,
      redirectUri: fixture.redirectUri,
      registeredRedirectUris: fixture.registeredRedirectUris,
      expectedState: syntheticState,
    }), /exact registered callback/);
  }
  assert.throws(() => validateSyntheticSmartAuthorizationResponse({
    callbackUrl: `${fixture.redirectUri}?code=x&code=y&state=${syntheticState}`,
    redirectUri: fixture.redirectUri,
    registeredRedirectUris: fixture.registeredRedirectUris,
    expectedState: syntheticState,
  }), /must not be repeated/);
});

test('PKCE helper generates a valid random S256 verifier and matching challenge', () => {
  const first = createPkcePair();
  const second = createPkcePair();
  assert.equal(first.method, 'S256');
  assert.match(first.verifier, /^[A-Za-z0-9_-]{43,128}$/);
  assert.match(first.challenge, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(
    first.challenge,
    createHash('sha256').update(first.verifier, 'ascii').digest('base64url'),
  );
  assert.notEqual(first.verifier, second.verifier);
  assert.notEqual(first.challenge, second.challenge);
});

test('report is deterministic even though state and PKCE material are ephemeral', () => {
  assert.deepEqual(
    buildSmartLaunchPreflightReport(fixture),
    buildSmartLaunchPreflightReport(fixture),
  );
});

test('strict fixture rejects extra fields and patient or token content', () => {
  assert.throws(() => validateSmartLaunchFixture(mutate((value) => {
    value.patient = 'Patient/123';
  })), /missing or unknown fields/);
  assert.throws(() => validateSmartLaunchFixture(mutate((value) => {
    value.access_token = 'synthetic-token';
  })), /missing or unknown fields/);
  assert.throws(() => validateSmartLaunchFixture(mutate((value) => {
    value.metadata.extra = true;
  })), /missing or unknown fields/);
});

test('fixture rejects non-HTTPS, non-synthetic, and non-canonical endpoints', () => {
  for (const value of [
    'http://ehr.example.org/fhir/r4',
    'https://ehr.example.com/fhir/r4',
    'https://user@ehr.example.org/fhir/r4',
    'https://ehr.example.org/fhir/r4?tenant=one',
    'https://ehr.example.org/fhir/r4#fragment',
  ]) {
    assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
      copy.fhirBaseUrl = value;
    })), /canonical HTTPS URL under example.org/);
  }
});

test('discovery URL appends the SMART well-known path to the complete FHIR base', () => {
  const parsed = validateSmartLaunchFixture(fixture);
  assert.equal(
    parsed.discoveryDocument.href,
    'https://ehr.example.org/fhir/r4/.well-known/smart-configuration',
  );
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.discoveryUrl = 'https://ehr.example.org/.well-known/smart-configuration';
  })), /append the SMART well-known path to fhirBaseUrl/);
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.discoveryUrl = 'https://auth.example.org/fhir/r4/.well-known/smart-configuration';
  })), /append the SMART well-known path to fhirBaseUrl/);
});

test('fixture rejects unregistered or ambiguous callback URLs', () => {
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.redirectUri = 'https://app.example.org/other/callback';
  })), /exactly match the single registered callback/);
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.registeredRedirectUris.push(copy.redirectUri);
  })), /must not contain duplicates/);
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.redirectUri = 'https://app.example.org/callback?next=patient';
    copy.registeredRedirectUris = [copy.redirectUri];
  })), /canonical HTTPS URL under example.org/);
});

test('fixture fails closed when auth-code, standalone, S256, or minimum scopes are absent', () => {
  const cases = [
    (copy) => { copy.metadata.grant_types_supported = ['client_credentials']; },
    (copy) => { copy.metadata.response_types_supported = ['token']; },
    (copy) => { copy.metadata.code_challenge_methods_supported = ['plain']; },
    (copy) => { copy.metadata.code_challenge_methods_supported.push('plain'); },
    (copy) => { copy.metadata.capabilities = ['launch-ehr']; },
    (copy) => {
      copy.metadata.capabilities = copy.metadata.capabilities.filter(
        (capability) => capability !== 'context-standalone-patient',
      );
    },
    (copy) => {
      copy.metadata.capabilities = copy.metadata.capabilities.filter(
        (capability) => capability !== 'client-public',
      );
    },
    (copy) => {
      copy.metadata.capabilities = copy.metadata.capabilities.filter(
        (capability) => capability !== 'permission-patient',
      );
    },
    (copy) => {
      copy.metadata.capabilities = copy.metadata.capabilities.filter(
        (capability) => capability !== 'permission-v2',
      );
    },
    (copy) => {
      copy.metadata.scopes_supported = ['launch/patient'];
    },
  ];
  for (const mutateCase of cases) {
    assert.throws(() => validateSmartLaunchFixture(mutate(mutateCase)));
  }
});

test('fixture rejects confidential clients, invalid versions, and malformed identifiers', () => {
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.clientType = 'confidential';
  })), /only a public client is supported/);
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.fhirVersion = '5.0.0';
  })), /FHIR version must be 4.0.1/);
  assert.throws(() => validateSmartLaunchFixture(mutate((copy) => {
    copy.clientId = 'client id with spaces';
  })), /bounded public-client identifier/);
});
