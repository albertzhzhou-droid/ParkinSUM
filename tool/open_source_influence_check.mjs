#!/usr/bin/env node
// Offline, fail-closed boundary for open-source research influences.
//
// This is not legal advice and does not decide license compatibility. It proves
// that every GitHub project already cited by the repository has a pinned,
// reviewed disposition and that concept-only research did not silently become
// copied, linked, vendored, derived, or distributed release content.

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inventoryPath = path.join(
  root,
  'config/open_source_influence_inventory.json',
);
const schemaUri =
  'https://parkinsum.app/schemas/open-source-influence-inventory/v1';
const commitPattern = /^[0-9a-f]{40}$/;
const safeIdPattern = /^[a-z0-9][a-z0-9._:-]*$/;
const spdxPattern = /^(NOASSERTION|[A-Za-z0-9][A-Za-z0-9.+-]*)$/;
const transferStatuses = new Set([
  'concept_only',
  'copied',
  'derived',
  'linked',
  'vendored',
]);
const licenseStatuses = new Set([
  'declared_not_machine_detected',
  'machine_detected',
  'unresolved',
]);
const artifactTypes = new Set([
  'api_contract',
  'data_asset',
  'documentation',
  'model_asset',
  'release_package',
  'report_asset',
  'source_code',
  'ui_pattern',
]);
const entryKeys = new Set([
  'artifactTypesReviewed',
  'copyingAuthorized',
  'declaredSpdx',
  'defaultBranch',
  'distributionAuthorized',
  'githubDetectedSpdx',
  'id',
  'licenseStatus',
  'localPaths',
  'obligations',
  'officialUrl',
  'pinnedCommit',
  'reviewedConcepts',
  'transferStatus',
]);
const ignoredDirectoryNames = new Set([
  '.dart_tool',
  '.git',
  'build',
  'node_modules',
]);

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function sameSet(left, right) {
  const a = sorted(new Set(left));
  const b = sorted(new Set(right));
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function finding(code, message, artifact = null) {
  return { code, message, artifact };
}

export function normalizeGitHubRepository(value) {
  if (typeof value !== 'string') return null;
  const match = value.match(
    /^https:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)(?:\/.*)?$/i,
  );
  if (!match) return null;
  const owner = match[1].toLowerCase();
  const repository = match[2].replace(/\.git$/i, '').toLowerCase();
  return `${owner}/${repository}`;
}

function walkFiles(candidate, output = []) {
  if (!existsSync(candidate)) return output;
  for (const entry of readdirSync(candidate, { withFileTypes: true })) {
    if (ignoredDirectoryNames.has(entry.name)) continue;
    const fullPath = path.join(candidate, entry.name);
    if (entry.isDirectory()) walkFiles(fullPath, output);
    else if (entry.isFile()) output.push(fullPath);
  }
  return output;
}

export function discoverGitHubRepositories(discoveryRoots, excluded = []) {
  const repositories = new Set();
  const excludedSet = new Set(excluded.map((value) => value.toLowerCase()));
  for (const relativeRoot of discoveryRoots) {
    const candidate = path.join(root, relativeRoot);
    const files = existsSync(candidate) && !readdirSafe(candidate)
      ? [candidate]
      : walkFiles(candidate);
    for (const file of files) {
      const text = readFileSync(file, 'utf8');
      for (const match of text.matchAll(
        /https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\/[^\s)\]}>"']*)?/gi,
      )) {
        const normalized = normalizeGitHubRepository(match[0]);
        if (normalized && !excludedSet.has(normalized)) {
          repositories.add(normalized);
        }
      }
    }
  }
  return sorted(repositories);
}

function readdirSafe(candidate) {
  try {
    readdirSync(candidate);
    return true;
  } catch {
    return false;
  }
}

export function discoverVendoredDirectories(directoryNames) {
  const matches = [];
  const productionRoots = [
    'android',
    'ios',
    'lib',
    'linux',
    'macos',
    'packages',
    'web',
    'windows',
  ];
  const forbidden = new Set(directoryNames);
  function visit(candidate) {
    if (!existsSync(candidate)) return;
    for (const entry of readdirSync(candidate, { withFileTypes: true })) {
      if (ignoredDirectoryNames.has(entry.name)) continue;
      const fullPath = path.join(candidate, entry.name);
      if (!entry.isDirectory()) continue;
      if (forbidden.has(entry.name)) {
        matches.push(path.relative(root, fullPath));
      } else {
        visit(fullPath);
      }
    }
  }
  for (const relativeRoot of productionRoots) visit(path.join(root, relativeRoot));
  return sorted(matches);
}

export function buildObservedInventory(inventory) {
  const discovery = inventory.discovery ?? {};
  return {
    githubRepositories: discoverGitHubRepositories(
      discovery.roots ?? [],
      discovery.excludedRepositories ?? [],
    ),
    vendoredDirectories: discoverVendoredDirectories(
      discovery.forbiddenVendoredDirectoryNames ?? [],
    ),
  };
}

function validateEntry(entry, releaseBoundary, findings) {
  if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
    findings.push(finding('invalid_influence', 'Influence entry must be an object.'));
    return;
  }
  const artifact = typeof entry.id === 'string' ? entry.id : null;
  if (!sameSet(Object.keys(entry), entryKeys)) {
    findings.push(
      finding(
        'unsupported_influence_shape',
        'Influence entry has missing or unsupported fields.',
        artifact,
      ),
    );
  }
  if (!safeIdPattern.test(entry.id ?? '')) {
    findings.push(finding('invalid_influence_id', 'Influence id is not safe.', artifact));
  }
  const normalizedUrl = normalizeGitHubRepository(entry.officialUrl);
  if (!normalizedUrl || entry.officialUrl.toLowerCase() !== `https://github.com/${normalizedUrl}`) {
    findings.push(
      finding(
        'noncanonical_official_url',
        'officialUrl must be a canonical two-segment GitHub repository URL.',
        artifact,
      ),
    );
  }
  if (!commitPattern.test(entry.pinnedCommit ?? '')) {
    findings.push(finding('invalid_pinned_commit', 'pinnedCommit must be a full SHA-1.', artifact));
  }
  if (typeof entry.defaultBranch !== 'string' || entry.defaultBranch.trim().length === 0) {
    findings.push(finding('missing_default_branch', 'defaultBranch is required.', artifact));
  }
  if (!spdxPattern.test(entry.declaredSpdx ?? '') || !spdxPattern.test(entry.githubDetectedSpdx ?? '')) {
    findings.push(finding('invalid_spdx', 'License identity must be SPDX-like or NOASSERTION.', artifact));
  }
  if (!licenseStatuses.has(entry.licenseStatus)) {
    findings.push(finding('invalid_license_status', 'licenseStatus is unsupported.', artifact));
  }
  if (
    entry.licenseStatus === 'machine_detected' &&
    (entry.declaredSpdx === 'NOASSERTION' ||
      entry.githubDetectedSpdx === 'NOASSERTION' ||
      entry.declaredSpdx !== entry.githubDetectedSpdx)
  ) {
    findings.push(finding('false_machine_detection', 'Machine-detected licenses must agree.', artifact));
  }
  if (
    entry.licenseStatus === 'unresolved' &&
    (entry.declaredSpdx !== 'NOASSERTION' || entry.githubDetectedSpdx !== 'NOASSERTION')
  ) {
    findings.push(finding('false_unresolved_license', 'Unresolved licenses must remain NOASSERTION.', artifact));
  }
  if (
    entry.licenseStatus === 'declared_not_machine_detected' &&
    (entry.declaredSpdx === 'NOASSERTION' ||
      entry.githubDetectedSpdx !== 'NOASSERTION')
  ) {
    findings.push(
      finding(
        'false_declared_license',
        'Declared-only status requires a declared SPDX id and GitHub NOASSERTION.',
        artifact,
      ),
    );
  }
  if (!transferStatuses.has(entry.transferStatus)) {
    findings.push(finding('invalid_transfer_status', 'transferStatus is unsupported.', artifact));
  }
  if (!Array.isArray(entry.artifactTypesReviewed) || entry.artifactTypesReviewed.length === 0) {
    findings.push(finding('missing_artifact_types', 'At least one reviewed artifact type is required.', artifact));
  } else if (
    entry.artifactTypesReviewed.some((value) => !artifactTypes.has(value)) ||
    new Set(entry.artifactTypesReviewed).size !== entry.artifactTypesReviewed.length
  ) {
    findings.push(finding('invalid_artifact_types', 'Artifact types must be unique and allowed.', artifact));
  }
  if (
    !Array.isArray(entry.reviewedConcepts) ||
    entry.reviewedConcepts.length === 0 ||
    entry.reviewedConcepts.some(
      (value) => typeof value !== 'string' || value.trim().length === 0,
    )
  ) {
    findings.push(finding('missing_reviewed_concepts', 'Reviewed concepts are required.', artifact));
  }
  for (const key of ['localPaths', 'obligations']) {
    if (!Array.isArray(entry[key])) {
      findings.push(finding(`invalid_${key}`, `${key} must be an array.`, artifact));
    }
  }
  const localPaths = Array.isArray(entry.localPaths) ? entry.localPaths : [];
  const obligations = Array.isArray(entry.obligations) ? entry.obligations : [];
  const isSortedUnique = (values) =>
    values.every(
      (value, index) =>
        typeof value === 'string' &&
        (index === 0 || values[index - 1].localeCompare(value) < 0),
    );
  if (
    !isSortedUnique(localPaths) ||
    !isSortedUnique(obligations)
  ) {
    findings.push(
      finding(
        'noncanonical_transfer_metadata',
        'Transfer paths and obligations must be unique.',
        artifact,
      ),
    );
  }
  if (entry.transferStatus === 'concept_only') {
    if (
      entry.copyingAuthorized !== false ||
      entry.distributionAuthorized !== false ||
      localPaths.length !== 0 ||
      obligations.length !== 0
    ) {
      findings.push(
        finding(
          'concept_only_boundary_violation',
          'Concept-only research cannot authorize or identify local upstream artifacts.',
          artifact,
        ),
      );
    }
    return;
  }

  if (entry.licenseStatus === 'unresolved') {
    findings.push(
      finding('unresolved_license_transfer', 'NOASSERTION cannot cross the release boundary.', artifact),
    );
  }
  if (
    entry.copyingAuthorized !== true ||
    entry.distributionAuthorized !== true ||
    localPaths.length === 0
  ) {
    findings.push(
      finding('transfer_not_authorized', 'Non-concept transfer requires authorization and local paths.', artifact),
    );
  }
  if (!releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.includes(entry.id)) {
    findings.push(
      finding('release_boundary_omission', 'Transferred influence is absent from releaseBoundary.', artifact),
    );
  }
  for (const localPath of localPaths) {
    if (typeof localPath !== 'string' || !existsSync(path.join(root, localPath))) {
      findings.push(finding('missing_transferred_path', 'Transferred local path is missing.', artifact));
    }
  }
  const reciprocal = /^(A?GPL)-/.test(entry.declaredSpdx ?? '');
  const required = reciprocal
    ? ['legal_compatibility_review', 'license_notice', 'source_disclosure']
    : ['license_notice'];
  for (const obligation of required) {
    if (!obligations.includes(obligation)) {
      findings.push(
        finding('missing_license_obligation', `Missing obligation: ${obligation}.`, artifact),
      );
    }
  }
}

export function validateInfluenceInventory(inventory, observed) {
  const findings = [];
  if (!inventory || typeof inventory !== 'object' || Array.isArray(inventory)) {
    return [finding('invalid_inventory', 'Inventory root must be an object.')];
  }
  if (inventory.$schema !== schemaUri || inventory.schemaVersion !== 1) {
    findings.push(finding('unsupported_schema', 'Expected influence inventory schema v1.'));
  }
  const review = inventory.review ?? {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(review.reviewedAt ?? '')) {
    findings.push(finding('invalid_review_date', 'reviewedAt must be YYYY-MM-DD.'));
  }
  if (!safeIdPattern.test(review.reviewerRole ?? '')) {
    findings.push(finding('invalid_reviewer_role', 'reviewerRole must be a safe identifier.'));
  }
  if (review.legalApproval !== 'not_requested_concept_only') {
    findings.push(
      finding('unsupported_legal_approval', 'Current inventory has no external legal approval.'),
    );
  }
  const releaseBoundary = inventory.releaseBoundary ?? {};
  for (const key of [
    'copiedLinkedVendoredOrDerivedInfluenceIds',
    'distributedUpstreamArtifactPaths',
    'dependencyEvidence',
  ]) {
    if (!Array.isArray(releaseBoundary[key])) {
      findings.push(finding('invalid_release_boundary', `${key} must be an array.`));
    }
  }
  for (const evidencePath of releaseBoundary.dependencyEvidence ?? []) {
    if (typeof evidencePath !== 'string' || !existsSync(path.join(root, evidencePath))) {
      findings.push(finding('missing_dependency_evidence', 'Dependency evidence is missing.', evidencePath));
    }
  }
  if (releaseBoundary.networkRefreshRequiredForOfflineGate !== false) {
    findings.push(finding('network_dependent_gate', 'The committed gate must remain offline.'));
  }
  if (
    typeof releaseBoundary.licenseNoticeMechanism !== 'string' ||
    releaseBoundary.licenseNoticeMechanism.trim().length === 0
  ) {
    findings.push(
      finding('missing_notice_mechanism', 'A release license-notice mechanism is required.'),
    );
  }
  const influences = inventory.influences;
  if (!Array.isArray(influences) || influences.length === 0) {
    findings.push(finding('missing_influences', 'At least one influence is required.'));
    return findings;
  }
  const ids = influences.map((entry) => entry?.id);
  const urls = influences.map((entry) => normalizeGitHubRepository(entry?.officialUrl));
  if (new Set(ids).size !== ids.length) {
    findings.push(finding('duplicate_influence_id', 'Influence ids must be unique.'));
  }
  if (new Set(urls).size !== urls.length) {
    findings.push(finding('duplicate_influence_url', 'Influence repositories must be unique.'));
  }
  if (!ids.every((value, index) => index === 0 || ids[index - 1].localeCompare(value) < 0)) {
    findings.push(finding('unsorted_influences', 'Influences must be sorted by id.'));
  }
  for (const entry of influences) validateEntry(entry, releaseBoundary, findings);
  const transferredIds = influences
    .filter((entry) => entry.transferStatus !== 'concept_only')
    .map((entry) => entry.id);
  if (
    !sameSet(
      transferredIds,
      releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds ?? [],
    )
  ) {
    findings.push(
      finding(
        'release_boundary_identity_drift',
        'Transferred influence identities and releaseBoundary differ.',
      ),
    );
  }
  const linkedVersionEvidence = releaseBoundary.linkedVersionEvidence ?? {};
  if (!sameSet(Object.keys(linkedVersionEvidence), transferredIds)) {
    findings.push(
      finding(
        'linked_version_evidence_drift',
        'Every transferred influence requires one exact linked-version record.',
      ),
    );
  }
  for (const entry of influences.filter(
    (candidate) => candidate.transferStatus !== 'concept_only',
  )) {
    const evidence = linkedVersionEvidence[entry.id];
    if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
      continue;
    }
    const sourcePath = evidence.versionSource;
    const version = evidence.version;
    if (
      typeof sourcePath !== 'string' ||
      typeof version !== 'string' ||
      !existsSync(path.join(root, sourcePath)) ||
      !readFileSync(path.join(root, sourcePath), 'utf8').includes(version)
    ) {
      findings.push(
        finding(
          'linked_version_source_mismatch',
          'Linked version is not present in its reviewed source file.',
          entry.id,
        ),
      );
    }
    if (evidence.sourceRevision !== entry.pinnedCommit) {
      findings.push(
        finding(
          'linked_source_revision_mismatch',
          'Linked source revision differs from the influence pin.',
          entry.id,
        ),
      );
    }
  }
  if (!sameSet(urls.filter(Boolean), observed.githubRepositories ?? [])) {
    findings.push(
      finding(
        'influence_discovery_drift',
        'Documented GitHub influences and the reviewed inventory differ.',
      ),
    );
  }
  if (
    !sameSet(
      releaseBoundary.distributedUpstreamArtifactPaths ?? [],
      observed.vendoredDirectories ?? [],
    )
  ) {
    findings.push(
      finding(
        'vendored_artifact_drift',
        'Observed vendored directories do not match the reviewed release boundary.',
      ),
    );
  }
  return findings;
}

export function runInfluenceCheck() {
  const inventory = JSON.parse(readFileSync(inventoryPath, 'utf8'));
  const observed = buildObservedInventory(inventory);
  const findings = validateInfluenceInventory(inventory, observed);
  if (findings.length > 0) {
    for (const item of findings) {
      console.error(
        `[${item.code}] ${item.message}${item.artifact ? ` (${item.artifact})` : ''}`,
      );
    }
    return 1;
  }
  const unresolved = inventory.influences.filter(
    (entry) => entry.licenseStatus === 'unresolved',
  ).length;
  console.log(
    `Open-source influence firewall passed: ${inventory.influences.length} pinned influences, ` +
      `${unresolved} unresolved licenses held concept-only, 0 transferred upstream artifacts.`,
  );
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(runInfluenceCheck());
}
