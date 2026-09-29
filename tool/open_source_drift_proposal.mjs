#!/usr/bin/env node
// Read-only, metadata-only proposal builder for reviewed upstream references.
// It never edits the influence inventory and never downloads source trees.

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { validateAcceptedOpenSourceBaseline } from './open_source_drift_decision_ledger.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const schemaUri = 'https://parkinsum.app/schemas/open-source-drift-proposal/v1';
const githubApiVersion = '2026-03-10';
const commitPattern = /^[0-9a-f]{40}$/i;
const spdxPattern = /^(?:NOASSERTION|[A-Za-z0-9][A-Za-z0-9.+-]*)$/;
const supportedHosts = new Set(['github.com', 'gitlab.com', 'bitbucket.org']);
const allowedTransferStatuses = new Set([
  'concept_only',
  'development_linked',
  'copied',
  'linked',
  'vendored',
  'derived',
]);
const allowedLicenseStatuses = new Set([
  'declared_not_machine_detected',
  'machine_detected',
  'unresolved',
]);
const maxBodyBytes = 1024 * 1024;
const defaultMaxTagPages = 10;
const defaultMaxHistoryCommits = 32;
class ApiFailure extends Error {
  constructor(code, message, requestEvent = null) {
    super(message);
    this.name = 'ApiFailure';
    this.code = code;
    this.requestEvent = requestEvent;
  }
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function stableText(value) {
  return JSON.stringify(value, null, 2) + '\n';
}

function assertObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
}

function validateInventory(inventory) {
  assertObject(inventory, 'Inventory');
  if (
    inventory.$schema !==
      'https://parkinsum.app/schemas/open-source-influence-inventory/v7' ||
    inventory.schemaVersion !== 7 ||
    !Array.isArray(inventory.influences) ||
    inventory.influences.length === 0
  ) {
    throw new Error('Unsupported or malformed open-source influence inventory');
  }
  const ids = new Set();
  const repositories = new Set();
  for (const entry of inventory.influences) {
    assertObject(entry, 'Influence entry');
    if (
      typeof entry.id !== 'string' ||
      !/^[a-z0-9][a-z0-9._:-]*$/.test(entry.id) ||
      ids.has(entry.id) ||
      typeof entry.officialUrl !== 'string' ||
      !commitPattern.test(entry.pinnedCommit ?? '') ||
      !spdxPattern.test(entry.declaredSpdx ?? '') ||
      !spdxPattern.test(entry.repositoryDetectedSpdx ?? '') ||
      typeof entry.defaultBranch !== 'string' ||
      entry.defaultBranch.trim().length === 0 ||
      !allowedTransferStatuses.has(entry.transferStatus) ||
      !allowedLicenseStatuses.has(entry.licenseStatus)
    ) {
      throw new Error(`Malformed or duplicate influence entry: ${entry.id ?? '(missing id)'}`);
    }
    let source;
    try {
      source = new URL(entry.officialUrl);
    } catch {
      throw new Error(`Invalid officialUrl for ${entry.id}`);
    }
    if (
      source.protocol !== 'https:' ||
      !supportedHosts.has(source.hostname.toLowerCase()) ||
      source.username ||
      source.password ||
      source.port ||
      source.search ||
      source.hash
    ) {
      throw new Error(`Unsupported officialUrl for ${entry.id}`);
    }
    const segments = source.pathname.split('/').filter(Boolean);
    if (segments.length !== 2 || segments.some((part) => part === '.' || part === '..')) {
      throw new Error(`officialUrl must identify a canonical repository for ${entry.id}`);
    }
    let decodedSegments;
    try {
      decodedSegments = segments.map((part) => decodeURIComponent(part));
    } catch {
      throw new Error(`officialUrl contains malformed path encoding for ${entry.id}`);
    }
    if (decodedSegments.some((part) => part.includes('/'))) {
      throw new Error(`officialUrl must not encode extra path segments for ${entry.id}`);
    }
    const normalizedRepository = `${source.hostname.toLowerCase()}/${decodedSegments.map((part) => part.replace(/\.git$/i, '').toLowerCase()).join('/')}`;
    if (repositories.has(normalizedRepository)) {
      throw new Error(`Duplicate source repository identity: ${normalizedRepository}`);
    }
    repositories.add(normalizedRepository);
    if (
      (entry.licenseStatus === 'machine_detected' &&
        (entry.declaredSpdx === 'NOASSERTION' ||
          entry.repositoryDetectedSpdx === 'NOASSERTION' ||
          entry.declaredSpdx !== entry.repositoryDetectedSpdx)) ||
      (entry.licenseStatus === 'unresolved' &&
        (entry.declaredSpdx !== 'NOASSERTION' || entry.repositoryDetectedSpdx !== 'NOASSERTION')) ||
      (entry.licenseStatus === 'declared_not_machine_detected' &&
        (entry.declaredSpdx === 'NOASSERTION' || entry.repositoryDetectedSpdx !== 'NOASSERTION'))
    ) {
      throw new Error(`Inconsistent license status for ${entry.id}`);
    }
    ids.add(entry.id);
  }
  return inventory.influences;
}

function sourceIdentity(entry) {
  const source = new URL(entry.officialUrl);
  const [namespace, repository] = source.pathname.split('/').filter(Boolean);
  return {
    host: source.hostname.toLowerCase(),
    namespace: decodeURIComponent(namespace).toLowerCase(),
    repository: decodeURIComponent(repository.replace(/\.git$/i, '')).toLowerCase(),
    normalized: `${source.hostname.toLowerCase()}/${decodeURIComponent(namespace).toLowerCase()}/${decodeURIComponent(repository.replace(/\.git$/i, '')).toLowerCase()}`,
  };
}

function rateLimitFrom(headers) {
  const remaining = headers.get('x-ratelimit-remaining');
  const reset = headers.get('x-ratelimit-reset');
  const retryAfter = headers.get('retry-after');
  const resetSeconds = reset !== null && /^\d+$/.test(reset) ? Number(reset) : null;
  const resetDate = resetSeconds !== null && Number.isSafeInteger(resetSeconds)
    ? new Date(resetSeconds * 1000)
    : null;
  return {
    state:
      remaining === '0' || retryAfter !== null
        ? 'limited_or_retry_after'
        : remaining !== null
          ? 'available'
          : 'not_exposed_by_provider',
    remaining: remaining !== null && /^\d+$/.test(remaining) ? Number(remaining) : null,
    resetAt: resetDate && Number.isFinite(resetDate.getTime())
      ? resetDate.toISOString()
      : null,
    retryAfterSeconds: retryAfter !== null && /^\d+$/.test(retryAfter)
      ? Number(retryAfter)
      : null,
  };
}

function selectedApiVersion(host, headers) {
  if (host === 'github.com') {
    return headers.get('x-github-api-version-selected') ?? githubApiVersion;
  }
  if (host === 'gitlab.com') return 'GitLab REST API v4';
  return 'Bitbucket Cloud REST API 2.0';
}

function requestPath(url) {
  const parsed = new URL(url);
  return `${parsed.host}${parsed.pathname}`;
}

function requestHeaders(host, token) {
  const headers = {
    accept: 'application/json',
    'user-agent': 'ParkinSUM-open-source-drift-proposal/1.0',
  };
  if (host === 'github.com') {
    headers['x-github-api-version'] = githubApiVersion;
    headers.accept = 'application/vnd.github+json';
    if (token) headers.authorization = `Bearer ${token}`;
  }
  return headers;
}

async function getJson(url, { host, token, fetchImpl, events, kind }) {
  let response;
  try {
    response = await fetchImpl(url, {
      method: 'GET',
      headers: requestHeaders(host, token),
      redirect: 'manual',
      signal: AbortSignal.timeout(20_000),
    });
  } catch (error) {
    const event = {
      kind,
      request: requestPath(url),
      status: 'network_error',
      apiVersion: host === 'github.com'
        ? githubApiVersion
        : host === 'gitlab.com'
          ? 'GitLab REST API v4'
          : 'Bitbucket Cloud REST API 2.0',
      rateLimit: null,
      detail: error?.name === 'TimeoutError' ? 'request_timeout' : 'transport_failure',
    };
    events.push(event);
    throw new ApiFailure('transport_failure', `Unable to retrieve ${kind}`, event);
  }

  const event = {
    kind,
    request: requestPath(url),
    status: response.status >= 200 && response.status < 300 ? 'retrieved' : 'http_error',
    httpStatus: response.status,
    apiVersion: selectedApiVersion(host, response.headers),
    rateLimit: rateLimitFrom(response.headers),
    redirectTarget: null,
  };
  events.push(event);
  if (response.status >= 300 && response.status < 400) {
    const location = response.headers.get('location');
    event.status = 'redirected';
    if (location) {
      try {
        const target = new URL(location, url);
        event.redirectTarget = `${target.host}${target.pathname}`;
      } catch {
        event.redirectTarget = 'malformed_location';
      }
    }
    throw new ApiFailure('repository_redirected', `Provider redirected ${kind}`, event);
  }
  if (!response.ok) {
    if (response.status === 403 || response.status === 429) {
      event.status = 'rate_limited_or_forbidden';
      throw new ApiFailure('rate_limited_or_forbidden', `Provider rejected ${kind}`, event);
    }
    if (response.status === 404) {
      event.status = 'not_found';
      throw new ApiFailure('not_found', `${kind} was not found`, event);
    }
    throw new ApiFailure('http_error', `Provider returned ${response.status} for ${kind}`, event);
  }

  let text;
  try {
    text = await response.text();
  } catch {
    event.status = 'malformed_response';
    throw new ApiFailure('malformed_response', `Unable to read ${kind}`, event);
  }
  if (Buffer.byteLength(text, 'utf8') > maxBodyBytes) {
    event.status = 'malformed_response';
    throw new ApiFailure('response_too_large', `${kind} exceeded the metadata response limit`, event);
  }
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    event.status = 'malformed_response';
    throw new ApiFailure('malformed_response', `${kind} was not valid JSON`, event);
  }
  if (!data || typeof data !== 'object') {
    event.status = 'malformed_response';
    throw new ApiFailure('malformed_response', `${kind} was not a JSON object or array`, event);
  }
  return { data, headers: response.headers, event };
}

function apiRoot(identity) {
  const namespace = encodeURIComponent(identity.namespace);
  const repository = encodeURIComponent(identity.repository);
  if (identity.host === 'github.com') {
    return `https://api.github.com/repos/${namespace}/${repository}`;
  }
  if (identity.host === 'gitlab.com') {
    const projectPath = encodeURIComponent(`${identity.namespace}/${identity.repository}`);
    return new URL(`/api/v4/projects/${projectPath}`, 'https://gitlab.com').toString();
  }
  return `https://api.bitbucket.org/2.0/repositories/${namespace}/${repository}`;
}

function expectedMetadataUrl(host) {
  if (host === 'github.com') return 'https://api.github.com/';
  if (host === 'gitlab.com') return 'https://gitlab.com/';
  return 'https://api.bitbucket.org/';
}

function validatePaginationUrl(next, { host, expectedPathPrefix }) {
  const parsed = new URL(next);
  const allowedHost = new URL(expectedMetadataUrl(host)).host;
  if (
    parsed.protocol !== 'https:' ||
    parsed.host !== allowedHost ||
    parsed.pathname !== expectedPathPrefix
  ) {
    throw new ApiFailure('pagination_target_rejected', 'Pagination target escaped the expected API path');
  }
  return parsed.toString();
}

function nextGithubPage(headers, { host, expectedPathPrefix, currentPage }) {
  const link = headers.get('link');
  if (!link) return null;
  const match = link.match(/<([^>]+)>\s*;\s*rel="next"/i);
  if (!match) {
    if (/rel\s*=\s*"?next"?/i.test(link)) {
      throw new ApiFailure('pagination_incomplete', 'GitHub returned a malformed next-page link');
    }
    return null;
  }
  const target = validatePaginationUrl(match[1], { host, expectedPathPrefix });
  const targetUrl = new URL(target);
  if (
    targetUrl.searchParams.get('per_page') !== '100' ||
    Number(targetUrl.searchParams.get('page')) !== currentPage + 1
  ) {
    throw new ApiFailure('pagination_incomplete', 'GitHub pagination skipped or changed the expected page size');
  }
  return target;
}

async function collectGithubTags(entry, identity, pin, options, events) {
  const prefix = `${new URL(apiRoot(identity)).pathname}/tags`;
  let pageUrl = `${apiRoot(identity)}/tags?per_page=100&page=1`;
  const matching = [];
  const seenNames = new Set();
  let pages = 0;
  while (pageUrl) {
    if (pages >= options.maxTagPages) {
      throw new ApiFailure('pagination_incomplete', `Tag pagination limit reached for ${entry.id}`);
    }
    const result = await getJson(pageUrl, {
      host: identity.host,
      token: options.githubToken,
      fetchImpl: options.fetchImpl,
      events,
      kind: 'tags',
    });
    pages += 1;
    if (!Array.isArray(result.data)) {
      throw new ApiFailure('malformed_response', `GitHub tags response malformed for ${entry.id}`, result.event);
    }
    for (const tag of result.data) {
      const sha = tag?.commit?.sha;
      if (typeof tag?.name !== 'string' || !commitPattern.test(sha ?? '')) {
        throw new ApiFailure('malformed_response', `GitHub tag record malformed for ${entry.id}`, result.event);
      }
      if (seenNames.has(tag.name)) {
        throw new ApiFailure('pagination_incomplete', `GitHub tag pages duplicated a tag for ${entry.id}`, result.event);
      }
      seenNames.add(tag.name);
      if (sha.toLowerCase() === pin.toLowerCase()) {
        matching.push({ name: tag.name, commit: sha.toLowerCase() });
      }
    }
    pageUrl = nextGithubPage(result.headers, {
      host: identity.host,
      expectedPathPrefix: prefix,
      currentPage: pages,
    });
  }
  return { refs: matching.sort((a, b) => a.name.localeCompare(b.name)), complete: true, pages };
}

async function collectGitlabTags(entry, identity, pin, options, events) {
  const rootUrl = apiRoot(identity);
  let page = 1;
  const matching = [];
  const seenNames = new Set();
  let pages = 0;
  while (page) {
    if (pages >= options.maxTagPages) {
      throw new ApiFailure('pagination_incomplete', `Tag pagination limit reached for ${entry.id}`);
    }
    const url = new URL(`${rootUrl}/repository/tags`);
    url.searchParams.set('per_page', '100');
    url.searchParams.set('page', String(page));
    const result = await getJson(url.toString(), {
      host: identity.host,
      token: options.gitlabToken,
      fetchImpl: options.fetchImpl,
      events,
      kind: 'tags',
    });
    pages += 1;
    if (!Array.isArray(result.data)) {
      throw new ApiFailure('malformed_response', `GitLab tags response malformed for ${entry.id}`, result.event);
    }
    for (const tag of result.data) {
      const sha = tag?.commit?.id;
      if (typeof tag?.name !== 'string' || !commitPattern.test(sha ?? '')) {
        throw new ApiFailure('malformed_response', `GitLab tag record malformed for ${entry.id}`, result.event);
      }
      if (seenNames.has(tag.name)) {
        throw new ApiFailure('pagination_incomplete', `GitLab tag pages duplicated a tag for ${entry.id}`, result.event);
      }
      seenNames.add(tag.name);
      if (sha.toLowerCase() === pin.toLowerCase()) {
        matching.push({ name: tag.name, commit: sha.toLowerCase() });
      }
    }
    const nextPage = result.headers.get('x-next-page');
    if (nextPage === null || nextPage === '') {
      page = 0;
    } else if (/^\d+$/.test(nextPage) && Number(nextPage) === page + 1) {
      page = Number(nextPage);
    } else {
      throw new ApiFailure('pagination_incomplete', `Invalid GitLab pagination header for ${entry.id}`, result.event);
    }
  }
  return { refs: matching.sort((a, b) => a.name.localeCompare(b.name)), complete: true, pages };
}

async function collectBitbucketTags(entry, identity, pin, options, events) {
  const rootUrl = apiRoot(identity);
  const first = new URL(`${rootUrl}/refs/tags`);
  first.searchParams.set('pagelen', '100');
  let pageUrl = first.toString();
  const prefix = `${new URL(rootUrl).pathname}/refs/tags`;
  const matching = [];
  const seenNames = new Set();
  let pages = 0;
  while (pageUrl) {
    if (pages >= options.maxTagPages) {
      throw new ApiFailure('pagination_incomplete', `Tag pagination limit reached for ${entry.id}`);
    }
    pageUrl = validatePaginationUrl(pageUrl, { host: identity.host, expectedPathPrefix: prefix });
    const result = await getJson(pageUrl, {
      host: identity.host,
      token: options.bitbucketToken,
      fetchImpl: options.fetchImpl,
      events,
      kind: 'tags',
    });
    pages += 1;
    if (!Array.isArray(result.data.values)) {
      throw new ApiFailure('malformed_response', `Bitbucket tags response malformed for ${entry.id}`, result.event);
    }
    for (const tag of result.data.values) {
      const sha = tag?.target?.hash;
      if (
        typeof tag?.name !== 'string' ||
        tag?.target?.type !== 'commit' ||
        !commitPattern.test(sha ?? '')
      ) {
        throw new ApiFailure('malformed_response', `Bitbucket tag record malformed for ${entry.id}`, result.event);
      }
      if (seenNames.has(tag.name)) {
        throw new ApiFailure('pagination_incomplete', `Bitbucket tag pages duplicated a tag for ${entry.id}`, result.event);
      }
      seenNames.add(tag.name);
      if (sha.toLowerCase() === pin.toLowerCase()) {
        matching.push({ name: tag.name, commit: sha.toLowerCase() });
      }
    }
    pageUrl = result.data.next
      ? validatePaginationUrl(result.data.next, {
          host: identity.host,
          expectedPathPrefix: prefix,
        })
      : null;
  }
  return { refs: matching.sort((a, b) => a.name.localeCompare(b.name)), complete: true, pages };
}

async function githubHistoryRelation(entry, identity, pinSha, headSha, options, events) {
  if (pinSha.toLowerCase() === headSha.toLowerCase()) {
    return { relation: 'identical', commitObjectsRead: 0, complete: true };
  }
  const base = apiRoot(identity);
  const queue = [{ sha: headSha.toLowerCase(), depth: 0 }];
  const visited = new Set();
  let commitObjectsRead = 0;
  while (queue.length > 0) {
    const current = queue.shift();
    if (current.sha === pinSha.toLowerCase()) {
      return { relation: 'ahead', commitObjectsRead, complete: true };
    }
    if (visited.has(current.sha)) continue;
    visited.add(current.sha);
    if (commitObjectsRead >= options.maxHistoryCommits) {
      return {
        relation: 'unverified_history_limit',
        commitObjectsRead,
        complete: false,
      };
    }
    const result = await getJson(`${base}/git/commits/${current.sha}`, {
      host: identity.host,
      token: options.githubToken,
      fetchImpl: options.fetchImpl,
      events,
      kind: 'history_commit_object',
    });
    commitObjectsRead += 1;
    if (
      result.data?.sha?.toLowerCase() !== current.sha ||
      !Array.isArray(result.data?.parents)
    ) {
      throw new ApiFailure('malformed_response', `GitHub commit parent metadata malformed for ${entry.id}`, result.event);
    }
    const parents = [];
    for (const parent of result.data.parents) {
      if (!commitPattern.test(parent?.sha ?? '')) {
        throw new ApiFailure('malformed_response', `GitHub commit parent SHA malformed for ${entry.id}`, result.event);
      }
      parents.push(parent.sha.toLowerCase());
    }
    if (parents.includes(pinSha.toLowerCase())) {
      return { relation: 'ahead', commitObjectsRead, complete: true };
    }
    for (const parentSha of parents) {
      if (!visited.has(parentSha)) queue.push({ sha: parentSha, depth: current.depth + 1 });
    }
  }
  return { relation: 'diverged', commitObjectsRead, complete: true };
}

function licenseEvidence({ detectedSpdx, key, source }) {
  const detected = typeof detectedSpdx === 'string' && spdxPattern.test(detectedSpdx)
    ? detectedSpdx
    : 'NOASSERTION';
  return {
    declaredSpdx: 'NOASSERTION',
    declaredEvidenceStatus: 'not_extracted_from_license_text',
    detectedSpdx: detected,
    detectorKey: typeof key === 'string' ? key : null,
    source,
    status: detected === 'NOASSERTION' ? 'unverified' : 'provider_detected',
  };
}

function canonicalObservedIdentity(host, value) {
  if (host === 'github.com') {
    return typeof value?.full_name === 'string' ? `github.com/${value.full_name.toLowerCase()}` : null;
  }
  if (host === 'gitlab.com') {
    return typeof value?.path_with_namespace === 'string'
      ? `gitlab.com/${value.path_with_namespace.toLowerCase()}`
      : null;
  }
  return typeof value?.full_name === 'string' ? `bitbucket.org/${value.full_name.toLowerCase()}` : null;
}

function rootLicense(host, metadata) {
  if (host === 'github.com') {
    const license = metadata.license;
    return licenseEvidence({
      detectedSpdx: license?.spdx_id,
      key: license?.key,
      source: 'github_repository_license_metadata',
    });
  }
  if (host === 'gitlab.com') {
    const license = metadata.license;
    return licenseEvidence({
      detectedSpdx: license?.spdx_id,
      key: license?.key,
      source: 'gitlab_project_license_metadata',
    });
  }
  return licenseEvidence({
    detectedSpdx: null,
    key: null,
    source: 'bitbucket_cloud_repository_metadata_does_not_expose_detected_spdx',
  });
}

async function observeGithub(entry, identity, options, events) {
  const base = apiRoot(identity);
  const repoResult = await getJson(base, {
    host: identity.host,
    token: options.githubToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'repository',
  });
  const metadata = repoResult.data;
  if (
    typeof metadata.full_name !== 'string' ||
    typeof metadata.default_branch !== 'string' ||
    typeof metadata.archived !== 'boolean'
  ) {
    throw new ApiFailure('malformed_response', `GitHub repository metadata malformed for ${entry.id}`, repoResult.event);
  }
  const observedIdentity = canonicalObservedIdentity(identity.host, metadata);
  const pinResult = await getJson(`${base}/git/commits/${entry.pinnedCommit}`, {
    host: identity.host,
    token: options.githubToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'pinned_commit',
  });
  const pinSha = pinResult.data?.sha;
  if (!commitPattern.test(pinSha ?? '')) {
    throw new ApiFailure('malformed_response', `GitHub pinned commit malformed for ${entry.id}`, pinResult.event);
  }
  const branchRef = `heads/${metadata.default_branch.split('/').map(encodeURIComponent).join('/')}`;
  const branchResult = await getJson(`${base}/git/ref/${branchRef}`, {
    host: identity.host,
    token: options.githubToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'default_branch_head',
  });
  const headSha = branchResult.data?.object?.sha;
  if (
    branchResult.data?.object?.type !== 'commit' ||
    branchResult.data?.ref !== `refs/heads/${metadata.default_branch}` ||
    !commitPattern.test(headSha ?? '')
  ) {
    throw new ApiFailure('malformed_response', `GitHub branch head malformed for ${entry.id}`, branchResult.event);
  }
  const history = await githubHistoryRelation(entry, identity, pinSha, headSha, options, events);
  const tags = await collectGithubTags(entry, identity, pinSha, options, events);
  return {
    repositoryIdentity: observedIdentity,
    canonicalUrl: typeof metadata.html_url === 'string' ? metadata.html_url : null,
    defaultBranch: metadata.default_branch,
    defaultBranchHead: headSha.toLowerCase(),
    pinnedCommit: pinSha.toLowerCase(),
    pinResolves: pinSha.toLowerCase() === entry.pinnedCommit.toLowerCase(),
    archived: metadata.archived,
    moved: observedIdentity !== sourceIdentity(entry).normalized,
    historyRelation: history.relation,
    historyTraversal: {
      commitObjectsRead: history.commitObjectsRead,
      complete: history.complete,
      maximumCommitObjects: options.maxHistoryCommits,
    },
    releaseOrTagIdentity: {
      kind: tags.refs.length > 0 ? 'tag' : 'commit',
      refsAtPinnedCommit: tags.refs,
      status: 'observed',
    },
    tagsPagination: { pages: tags.pages, complete: tags.complete },
    license: rootLicense(identity.host, metadata),
    apiVersion: githubApiVersion,
  };
}

async function observeGitlab(entry, identity, options, events) {
  const base = apiRoot(identity);
  const projectResult = await getJson(base, {
    host: identity.host,
    token: options.gitlabToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'repository',
  });
  const metadata = projectResult.data;
  if (
    !Number.isSafeInteger(metadata.id) ||
    metadata.id < 1 ||
    typeof metadata.path_with_namespace !== 'string' ||
    typeof metadata.default_branch !== 'string' ||
    typeof metadata.archived !== 'boolean'
  ) {
    throw new ApiFailure('malformed_response', `GitLab project metadata malformed for ${entry.id}`, projectResult.event);
  }
  const pinResult = await getJson(`${base}/repository/commits/${entry.pinnedCommit}`, {
    host: identity.host,
    token: options.gitlabToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'pinned_commit',
  });
  const pinSha = pinResult.data?.id;
  if (!commitPattern.test(pinSha ?? '')) {
    throw new ApiFailure('malformed_response', `GitLab pinned commit malformed for ${entry.id}`, pinResult.event);
  }
  const branchResult = await getJson(
    `${base}/repository/commits/${encodeURIComponent(metadata.default_branch)}`,
    {
      host: identity.host,
      token: options.gitlabToken,
      fetchImpl: options.fetchImpl,
      events,
      kind: 'default_branch_head',
    },
  );
  const headSha = branchResult.data?.id;
  if (!commitPattern.test(headSha ?? '')) {
    throw new ApiFailure('malformed_response', `GitLab branch head malformed for ${entry.id}`, branchResult.event);
  }
  const tags = await collectGitlabTags(entry, identity, pinSha, options, events);
  const observedIdentity = canonicalObservedIdentity(identity.host, metadata);
  return {
    repositoryIdentity: observedIdentity,
    canonicalUrl: typeof metadata.web_url === 'string' ? metadata.web_url : null,
    defaultBranch: metadata.default_branch,
    defaultBranchHead: headSha.toLowerCase(),
    pinnedCommit: pinSha.toLowerCase(),
    pinResolves: pinSha.toLowerCase() === entry.pinnedCommit.toLowerCase(),
    archived: metadata.archived,
    moved: observedIdentity !== sourceIdentity(entry).normalized,
    historyRelation: 'unverified_provider_comparison_not_yet_supported',
    releaseOrTagIdentity: {
      kind: tags.refs.length > 0 ? 'tag' : 'commit',
      refsAtPinnedCommit: tags.refs,
      status: 'observed',
    },
    tagsPagination: { pages: tags.pages, complete: tags.complete },
    license: rootLicense(identity.host, metadata),
    apiVersion: 'GitLab REST API v4',
  };
}

async function observeBitbucket(entry, identity, options, events) {
  const base = apiRoot(identity);
  const repoResult = await getJson(base, {
    host: identity.host,
    token: options.bitbucketToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'repository',
  });
  const metadata = repoResult.data;
  const branch = metadata.mainbranch?.name;
  if (typeof metadata.full_name !== 'string' || typeof branch !== 'string') {
    throw new ApiFailure('malformed_response', `Bitbucket repository metadata malformed for ${entry.id}`, repoResult.event);
  }
  const pinResult = await getJson(`${base}/commit/${entry.pinnedCommit}`, {
    host: identity.host,
    token: options.bitbucketToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'pinned_commit',
  });
  const pinSha = pinResult.data?.hash;
  if (!commitPattern.test(pinSha ?? '')) {
    throw new ApiFailure('malformed_response', `Bitbucket pinned commit malformed for ${entry.id}`, pinResult.event);
  }
  const headUrl = new URL(`${base}/commits/${encodeURIComponent(branch)}`);
  headUrl.searchParams.set('pagelen', '1');
  const branchResult = await getJson(headUrl.toString(), {
    host: identity.host,
    token: options.bitbucketToken,
    fetchImpl: options.fetchImpl,
    events,
    kind: 'default_branch_head',
  });
  const headSha = branchResult.data?.values?.[0]?.hash;
  if (!commitPattern.test(headSha ?? '')) {
    throw new ApiFailure('malformed_response', `Bitbucket branch head malformed for ${entry.id}`, branchResult.event);
  }
  const tags = await collectBitbucketTags(entry, identity, pinSha, options, events);
  const observedIdentity = canonicalObservedIdentity(identity.host, metadata);
  return {
    repositoryIdentity: observedIdentity,
    canonicalUrl: typeof metadata.links?.html?.href === 'string' ? metadata.links.html.href : null,
    defaultBranch: branch,
    defaultBranchHead: headSha.toLowerCase(),
    pinnedCommit: pinSha.toLowerCase(),
    pinResolves: pinSha.toLowerCase() === entry.pinnedCommit.toLowerCase(),
    archived: null,
    archiveStateStatus: 'not_exposed_by_bitbucket_cloud_repository_metadata',
    moved: observedIdentity !== sourceIdentity(entry).normalized,
    historyRelation: 'unverified_provider_comparison_not_yet_supported',
    releaseOrTagIdentity: {
      kind: tags.refs.length > 0 ? 'tag' : 'commit',
      refsAtPinnedCommit: tags.refs,
      status: 'observed',
    },
    tagsPagination: { pages: tags.pages, complete: tags.complete },
    license: rootLicense(identity.host, metadata),
    apiVersion: 'Bitbucket Cloud REST API 2.0',
  };
}

function priorRecord(previousProposal, id) {
  return previousProposal?.proposals?.find((record) => record.influenceId === id) ?? null;
}

function classifyObservedDrift(entry, observed, prior, retrievalError) {
  const reasons = [];
  const blockers = [];
  const unverified = [];
  if (retrievalError) {
    const code = retrievalError.code ?? 'retrieval_failure';
    const detail = retrievalError.message ?? 'upstream observation failed';
    if (code === 'repository_redirected' || code === 'identity_mismatch') blockers.push(code);
    else unverified.push(code);
    reasons.push({ code, detail });
  }
  if (observed) {
    if (observed.repositoryIdentity !== sourceIdentity(entry).normalized || observed.moved) {
      blockers.push('repository_identity_changed');
      reasons.push({ code: 'repository_identity_changed', detail: 'Observed canonical identity differs from the inventory.' });
    }
    if (observed.archived === true) {
      blockers.push('repository_archived');
      reasons.push({ code: 'repository_archived', detail: 'The upstream repository is archived.' });
    } else if (observed.archived === null || observed.archived === undefined) {
      unverified.push('archive_state_unavailable');
      reasons.push({ code: 'archive_state_unavailable', detail: 'The provider did not expose archive state.' });
    }
    if (observed.pinResolves !== true || observed.pinnedCommit !== entry.pinnedCommit.toLowerCase()) {
      blockers.push('pinned_commit_unavailable_or_mismatched');
      reasons.push({ code: 'pinned_commit_unavailable_or_mismatched', detail: 'The exact reviewed commit did not resolve to the requested full SHA.' });
    }
    if (!observed.defaultBranchHead || !commitPattern.test(observed.defaultBranchHead)) {
      unverified.push('default_branch_head_unavailable');
    }
    if (['diverged', 'behind'].includes(observed.historyRelation)) {
      blockers.push('history_relation_changed');
      reasons.push({ code: 'history_relation_changed', detail: `Pinned commit relation to the observed default branch is ${observed.historyRelation}.` });
    } else if (!['ahead', 'identical'].includes(observed.historyRelation)) {
      unverified.push('history_relation_unverified');
      reasons.push({ code: 'history_relation_unverified', detail: 'The provider response did not establish ancestry from the reviewed pin to the default branch.' });
    }
    if (!observed.tagsPagination?.complete) {
      unverified.push('tag_pagination_incomplete');
      reasons.push({ code: 'tag_pagination_incomplete', detail: 'Not all tag pages were observed.' });
    }
    if (observed.license?.detectedSpdx === 'NOASSERTION') {
      unverified.push('detected_license_noassertion');
      reasons.push({ code: 'detected_license_noassertion', detail: 'The provider did not return a machine-detected SPDX license.' });
    } else if (
      observed.license?.detectedSpdx &&
      observed.license.detectedSpdx !== entry.repositoryDetectedSpdx
    ) {
      blockers.push('detected_license_changed_from_inventory');
      reasons.push({ code: 'detected_license_changed_from_inventory', detail: 'Provider-detected SPDX evidence differs from the reviewed inventory.' });
    }
    if (observed.license?.declaredSpdx === 'NOASSERTION') {
      unverified.push('declared_license_not_observed');
      reasons.push({ code: 'declared_license_not_observed', detail: 'The workflow does not fetch or parse repository license text.' });
    }
  }
  if (!prior) {
    unverified.push('no_prior_drift_snapshot');
    reasons.push({ code: 'no_prior_drift_snapshot', detail: 'This is a first observation; tag, identity, and license changes cannot be compared to a prior snapshot.' });
  } else if (observed) {
    const previousObserved = prior.observed;
    if (!previousObserved) {
      unverified.push('prior_observation_missing');
      reasons.push({ code: 'prior_observation_missing', detail: 'Previous proposal had no complete observation for this influence.' });
    } else {
      const currentTags = observed.releaseOrTagIdentity?.refsAtPinnedCommit ?? [];
      const oldTags = previousObserved.releaseOrTagIdentity?.refsAtPinnedCommit ?? [];
      if (JSON.stringify(currentTags) !== JSON.stringify(oldTags)) {
        blockers.push('tag_identity_changed');
        reasons.push({ code: 'tag_identity_changed', detail: 'Tag references at the reviewed commit differ from the previous proposal.' });
      }
      const oldLicense = previousObserved.license?.detectedSpdx;
      const currentLicense = observed.license?.detectedSpdx;
      if (oldLicense !== currentLicense) {
        blockers.push('detected_license_drift');
        reasons.push({ code: 'detected_license_drift', detail: 'Detected license evidence differs from the previous proposal.' });
      }
      if (previousObserved.defaultBranch !== observed.defaultBranch) {
        reasons.push({ code: 'default_branch_name_changed', detail: 'The default branch name changed and requires semantic review.' });
      }
      if (previousObserved.defaultBranchHead !== observed.defaultBranchHead) {
        reasons.push({ code: 'default_branch_head_advanced', detail: 'The default branch head advanced since the previous observation.' });
      }
      if (previousObserved.repositoryIdentity !== observed.repositoryIdentity) {
        blockers.push('repository_identity_changed');
      }
      if (previousObserved.archived !== observed.archived) {
        reasons.push({ code: 'archive_state_changed', detail: 'Repository archive state changed since the previous observation.' });
        if (observed.archived === true) blockers.push('repository_archived');
      }
      if (previousObserved.historyRelation !== observed.historyRelation) {
        reasons.push({ code: 'history_relation_changed_since_previous', detail: 'Pinned-commit ancestry evidence changed since the previous observation.' });
      }
    }
  }

  const status = blockers.length > 0
    ? 'blocker'
    : unverified.length > 0
      ? 'unverified'
      : 'review_required';
  return {
    status,
    reasons,
    blockerCodes: [...new Set(blockers)].sort(),
    unverifiedCodes: [...new Set(unverified)].sort(),
  };
}

function priorInventoryMatches(previousProposal, previousDecisionLedger, inventoryDigest, influences) {
  if (!previousProposal) return { accepted: false, status: 'not_supplied' };
  if (
    previousProposal.$schema !== schemaUri ||
    previousProposal.schemaVersion !== 1 ||
    !Array.isArray(previousProposal.proposals)
  ) {
    return { accepted: false, status: 'previous_proposal_schema_invalid' };
  }
  if (previousProposal.inventory?.sha256 !== inventoryDigest) {
    return { accepted: false, status: 'previous_proposal_inventory_digest_mismatch' };
  }
  const expectedIds = new Set(influences.map((entry) => entry.id));
  const priorIds = previousProposal.proposals.map((record) => record?.influenceId);
  if (
    priorIds.length !== expectedIds.size ||
    new Set(priorIds).size !== priorIds.length ||
    priorIds.some((id) => !expectedIds.has(id))
  ) {
    return { accepted: false, status: 'previous_proposal_influence_set_mismatch' };
  }
  const entriesById = new Map(influences.map((entry) => [entry.id, entry]));
  const identityMatches = previousProposal.proposals.every((record) => {
    const entry = entriesById.get(record.influenceId);
    return (
      record.officialUrl === entry.officialUrl &&
      record.transferStatus === entry.transferStatus &&
      record.previous?.repositoryIdentity === sourceIdentity(entry).normalized &&
      record.previous?.pinnedCommit === entry.pinnedCommit.toLowerCase() &&
      record.previous?.defaultBranch === entry.defaultBranch &&
      record.previous?.declaredSpdx === entry.declaredSpdx &&
      record.previous?.detectedSpdx === entry.repositoryDetectedSpdx &&
      record.previous?.licenseStatus === entry.licenseStatus
    );
  });
  if (!identityMatches) {
    return { accepted: false, status: 'previous_proposal_inventory_identity_mismatch' };
  }
  if (!previousDecisionLedger) {
    return { accepted: false, status: 'previous_proposal_decision_ledger_missing' };
  }
  const review = validateAcceptedOpenSourceBaseline(previousProposal, previousDecisionLedger);
  return review.accepted
    ? { accepted: true, status: 'reviewed_baseline' }
    : { accepted: false, status: `previous_proposal_${review.status}` };
}

async function mapLimit(items, concurrency, callback) {
  const results = new Array(items.length);
  let index = 0;
  async function worker() {
    while (true) {
      const current = index;
      index += 1;
      if (current >= items.length) return;
      results[current] = await callback(items[current], current);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, worker));
  return results;
}

async function observe(entry, options) {
  const identity = sourceIdentity(entry);
  const events = [];
  let observed = null;
  let failure = null;
  try {
    if (identity.host === 'github.com') {
      observed = await observeGithub(entry, identity, options, events);
    } else if (identity.host === 'gitlab.com') {
      observed = await observeGitlab(entry, identity, options, events);
    } else {
      observed = await observeBitbucket(entry, identity, options, events);
    }
  } catch (error) {
    failure = {
      code: error?.code ?? 'retrieval_failure',
      message: error?.message ?? 'Unable to observe upstream metadata',
    };
    if (error?.requestEvent && !events.includes(error.requestEvent)) events.push(error.requestEvent);
  }
  return { observed, events, failure };
}

export async function collectOpenSourceDriftProposal({
  inventory,
  inventoryText = stableText(inventory),
  previousProposal = null,
  previousDecisionLedger = null,
  reviewedAt = new Date().toISOString(),
  fetchImpl = fetch,
  githubToken = null,
  gitlabToken = null,
  bitbucketToken = null,
  maxTagPages = defaultMaxTagPages,
  maxHistoryCommits = defaultMaxHistoryCommits,
  concurrency = 3,
} = {}) {
  const influences = validateInventory(inventory);
  if (!Number.isFinite(Date.parse(reviewedAt)) || !reviewedAt.endsWith('Z')) {
    throw new Error('reviewedAt must be an ISO UTC timestamp');
  }
  if (!Number.isInteger(maxTagPages) || maxTagPages < 1 || maxTagPages > 500) {
    throw new Error('maxTagPages must be an integer between 1 and 500');
  }
  if (!Number.isInteger(maxHistoryCommits) || maxHistoryCommits < 1 || maxHistoryCommits > 512) {
    throw new Error('maxHistoryCommits must be an integer between 1 and 512');
  }
  if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 5) {
    throw new Error('concurrency must be between 1 and 5');
  }
  const inventoryDigest = sha256(inventoryText);
  const previousCheck = priorInventoryMatches(
    previousProposal,
    previousDecisionLedger,
    inventoryDigest,
    influences,
  );
  const previousAvailable = previousCheck.accepted;
  const previousProblem = previousProposal && !previousAvailable
    ? previousCheck.status
    : null;
  const options = {
    fetchImpl,
    githubToken,
    gitlabToken,
    bitbucketToken,
    maxTagPages,
    maxHistoryCommits,
  };
  const proposals = await mapLimit(influences, concurrency, async (entry) => {
    const source = sourceIdentity(entry);
    const previous = previousAvailable ? priorRecord(previousProposal, entry.id) : null;
    const { observed, events, failure } = await observe(entry, options);
    const retrievalFailure = failure ?? (previousProblem
      ? { code: previousProblem, message: 'Previous proposal or human-decision ledger did not validate against this inventory.' }
      : null);
    const comparison = classifyObservedDrift(entry, observed, previous, retrievalFailure);
    return {
      influenceId: entry.id,
      officialUrl: entry.officialUrl,
      transferStatus: entry.transferStatus,
      previous: {
        repositoryIdentity: source.normalized,
        pinnedCommit: entry.pinnedCommit.toLowerCase(),
        releaseOrTagIdentity: {
          status: 'not_recorded_in_inventory',
          value: null,
        },
        defaultBranch: entry.defaultBranch,
        declaredSpdx: entry.declaredSpdx,
        detectedSpdx: entry.repositoryDetectedSpdx,
        licenseStatus: entry.licenseStatus,
      },
      observed,
      retrieval: {
        status: failure ? 'incomplete' : 'metadata_only_complete',
        failure,
        requests: events,
        apiVersion: observed?.apiVersion ?? events[0]?.apiVersion ?? null,
        rateLimitStatus: events.some((event) => event.rateLimit?.state === 'limited_or_retry_after')
          ? 'limited_or_retry_after'
          : events.some((event) => event.rateLimit?.state === 'available')
            ? 'available'
            : 'not_exposed_or_unavailable',
        paginationStatus: observed?.tagsPagination?.complete === true
          ? 'complete'
          : 'incomplete_or_unavailable',
      },
      comparison,
      reviewer: {
        decision: null,
        changeClassification: [],
        reviewerIdentity: null,
        reviewedAt: null,
        notes: null,
      },
    };
  });
  const counts = Object.fromEntries(['blocker', 'unverified', 'review_required'].map((status) => [
    status,
    proposals.filter((proposal) => proposal.comparison.status === status).length,
  ]));
  const status = counts.blocker > 0
    ? 'blocker'
    : counts.unverified > 0
      ? 'unverified'
      : 'review_required';
  return {
    $schema: schemaUri,
    schemaVersion: 1,
    reportKind: 'upstream_metadata_drift_proposal',
    releaseDecision: 'not_a_release_decision',
    reviewedAt,
    inventory: {
      schemaVersion: inventory.schemaVersion,
      sha256: inventoryDigest,
      influenceCount: influences.length,
    },
    previousProposal: {
      available: previousAvailable,
      status: previousProblem ?? previousCheck.status,
    },
    collection: {
      mode: 'read_only_metadata_only',
      sourceTreeDownloaded: false,
      codeDownloaded: false,
      modelDataOrReportDownloaded: false,
      inventoryMutated: false,
      reviewerClassificationRequired: true,
      note: 'A successful metadata retrieval is not an approval. Review source semantics, transfer impact, notices, SBOM obligations, and scientific/model/data claims before updating any pinned inventory record.',
    },
    summary: { status, counts },
    proposals,
  };
}

function parseArgs(args) {
  const parsed = {
    output: 'build/open_source_drift_proposal/proposal.json',
    previousProposal: null,
    previousDecisionLedger: null,
  };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--help' || arg === '-h') {
      parsed.help = true;
    } else if (
      arg === '--output' ||
      arg === '--previous-proposal' ||
      arg === '--previous-decision-ledger'
    ) {
      const value = args[index + 1];
      if (!value || value.startsWith('--')) throw new Error(`${arg} requires a path`);
      const key = arg === '--output'
        ? 'output'
        : arg === '--previous-proposal'
          ? 'previousProposal'
          : 'previousDecisionLedger';
      parsed[key] = value;
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return parsed;
}

function usage() {
  return [
    'Usage: node tool/open_source_drift_proposal.mjs [--output PATH] [--previous-proposal PATH --previous-decision-ledger PATH]',
    'Reads config/open_source_influence_inventory.json and performs metadata-only public API checks.',
    'A previous proposal must match the inventory and include --previous-decision-ledger with a valid append-only human-review chain.',
    'No inventory or source tree is modified.',
  ].join('\n');
}

function repositoryPath(relativePath, label) {
  if (path.isAbsolute(relativePath)) {
    throw new Error(`${label} must be a repository-relative path`);
  }
  const resolved = path.resolve(root, relativePath);
  if (!resolved.startsWith(`${root}${path.sep}`)) {
    throw new Error(`${label} must stay inside the repository`);
  }
  return resolved;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  const inventoryPath = path.join(root, 'config/open_source_influence_inventory.json');
  const inventoryText = readFileSync(inventoryPath, 'utf8');
  const inventory = JSON.parse(inventoryText);
  const previousPath = args.previousProposal
    ? repositoryPath(args.previousProposal, '--previous-proposal')
    : null;
  const previousLedgerPath = args.previousDecisionLedger
    ? repositoryPath(args.previousDecisionLedger, '--previous-decision-ledger')
    : null;
  if (Boolean(previousPath) !== Boolean(previousLedgerPath)) {
    throw new Error('--previous-proposal and --previous-decision-ledger must be supplied together');
  }
  if (previousPath && !existsSync(previousPath)) {
    throw new Error(`Previous proposal does not exist: ${args.previousProposal}`);
  }
  if (previousLedgerPath && !existsSync(previousLedgerPath)) {
    throw new Error(`Previous decision ledger does not exist: ${args.previousDecisionLedger}`);
  }
  const previousProposal = previousPath
    ? JSON.parse(readFileSync(previousPath, 'utf8'))
    : null;
  const previousDecisionLedger = previousLedgerPath
    ? JSON.parse(readFileSync(previousLedgerPath, 'utf8'))
    : null;
  const proposal = await collectOpenSourceDriftProposal({
    inventory,
    inventoryText,
    previousProposal,
    previousDecisionLedger,
    githubToken: process.env.GITHUB_TOKEN ?? null,
    gitlabToken: process.env.GITLAB_TOKEN ?? null,
    bitbucketToken: process.env.BITBUCKET_TOKEN ?? null,
  });
  const outputPath = repositoryPath(args.output, '--output');
  mkdirSync(path.dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, stableText(proposal), { flag: 'w' });
  process.stdout.write(
    `Proposal generated: ${path.relative(root, outputPath)} (${proposal.summary.status}; ${proposal.inventory.influenceCount} repositories; ${proposal.summary.counts.blocker} blockers, ${proposal.summary.counts.unverified} unverified, ${proposal.summary.counts.review_required} review required). This is not a release approval.\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((error) => {
    process.stderr.write(`${error?.message ?? 'Upstream drift proposal failed'}\n`);
    process.exitCode = 1;
  });
}
