#!/usr/bin/env node
// Offline, fail-closed boundary for open-source research influences.
//
// This is not legal advice and does not decide license compatibility. It proves
// that every supported source repository cited by the project has a pinned,
// reviewed disposition and that concept-only research did not silently cross
// the release boundary or hide a development-only dependency link.

import { createHash } from 'node:crypto';
import {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  realpathSync,
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inventoryPath = path.join(
  root,
  'config/open_source_influence_inventory.json',
);
const schemaUri =
  'https://parkinsum.app/schemas/open-source-influence-inventory/v7';
const sourceHosts = new Set(['bitbucket.org', 'github.com', 'gitlab.com']);
const commitPattern = /^[0-9a-f]{40}$/;
const safeIdPattern = /^[a-z0-9][a-z0-9._:-]*$/;
const spdxPattern = /^(NOASSERTION|[A-Za-z0-9][A-Za-z0-9.+-]*)$/;
const transferStatuses = new Set([
  'concept_only',
  'copied',
  'derived',
  'development_linked',
  'linked',
  'vendored',
]);
const releaseTransferStatuses = new Set([
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
  'clinical_rule_asset',
  'data_asset',
  'documentation',
  'font_asset',
  'model_asset',
  'release_package',
  'report_asset',
  'source_code',
  'terminology_asset',
  'ui_pattern',
]);
const entryKeys = new Set([
  'artifactLicenseEvidence',
  'artifactTypesReviewed',
  'copyingAuthorized',
  'declaredSpdx',
  'defaultBranch',
  'distributionAuthorized',
  'repositoryDetectedSpdx',
  'id',
  'licenseStatus',
  'localPaths',
  'obligations',
  'officialUrl',
  'pinnedCommit',
  'reviewedConcepts',
  'transferStatus',
]);
const assetArtifactTypes = new Set([
  'clinical_rule_asset',
  'data_asset',
  'font_asset',
  'model_asset',
  'report_asset',
  'terminology_asset',
]);
const artifactLicenseEvidenceKeys = new Set([
  'artifactType',
  'assetScope',
  'declaredSpdx',
  'detectedSpdx',
  'licenseStatus',
  'localPaths',
  'reviewStatus',
  'sourceLocator',
  'obligations',
]);
const assetFileLicenseEvidenceKeys = new Set([
  'assetPath',
  'assetRole',
  'assetSha256',
  'artifactType',
  'declaredSpdx',
  'detectedSpdx',
  'derivationStatus',
  'influenceId',
  'licenseStatus',
  'noticePaths',
  'obligations',
  'pinnedCommit',
  'reviewStatus',
  'sourceLocator',
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
  const leftValues = Array.isArray(left)
    ? left
    : left instanceof Set
      ? [...left]
      : null;
  const rightValues = Array.isArray(right)
    ? right
    : right instanceof Set
      ? [...right]
      : null;
  if (
    !leftValues ||
    !rightValues ||
    !leftValues.every((value) => typeof value === 'string') ||
    !rightValues.every((value) => typeof value === 'string')
  ) {
    return false;
  }
  const a = sorted(new Set(leftValues));
  const b = sorted(new Set(rightValues));
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function finding(code, message, artifact = null) {
  return { code, message, artifact };
}

export function normalizeSourceRepository(value) {
  if (typeof value !== 'string') return null;
  const match = value.match(
    /^https:\/\/(github\.com|bitbucket\.org|gitlab\.com)\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)(?:\/.*)?$/i,
  );
  if (!match) return null;
  const host = match[1].toLowerCase();
  if (!sourceHosts.has(host)) return null;
  const workspace = match[2].toLowerCase();
  const repository = match[3].replace(/\.git$/i, '').toLowerCase();
  return `${host}/${workspace}/${repository}`;
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

export function discoverSourceRepositories(discoveryRoots, excluded = []) {
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
        /https:\/\/(?:github\.com|bitbucket\.org|gitlab\.com)\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\/[^\s)\]}>"']*)?/gi,
      )) {
        const normalized = normalizeSourceRepository(match[0]);
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
    sourceRepositories: discoverSourceRepositories(
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
  const normalizedUrl = normalizeSourceRepository(entry.officialUrl);
  if (!normalizedUrl || entry.officialUrl.toLowerCase() !== `https://${normalizedUrl}`) {
    findings.push(
      finding(
        'noncanonical_official_url',
        'officialUrl must be a canonical GitHub, GitLab, or Bitbucket repository URL.',
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
  if (!spdxPattern.test(entry.declaredSpdx ?? '') || !spdxPattern.test(entry.repositoryDetectedSpdx ?? '')) {
    findings.push(finding('invalid_spdx', 'License identity must be SPDX-like or NOASSERTION.', artifact));
  }
  if (!licenseStatuses.has(entry.licenseStatus)) {
    findings.push(finding('invalid_license_status', 'licenseStatus is unsupported.', artifact));
  }
  if (
    entry.licenseStatus === 'machine_detected' &&
    (entry.declaredSpdx === 'NOASSERTION' ||
      entry.repositoryDetectedSpdx === 'NOASSERTION' ||
      entry.declaredSpdx !== entry.repositoryDetectedSpdx)
  ) {
    findings.push(finding('false_machine_detection', 'Machine-detected licenses must agree.', artifact));
  }
  if (
    entry.licenseStatus === 'unresolved' &&
    (entry.declaredSpdx !== 'NOASSERTION' || entry.repositoryDetectedSpdx !== 'NOASSERTION')
  ) {
    findings.push(finding('false_unresolved_license', 'Unresolved licenses must remain NOASSERTION.', artifact));
  }
  if (
    entry.licenseStatus === 'declared_not_machine_detected' &&
    (entry.declaredSpdx === 'NOASSERTION' ||
      entry.repositoryDetectedSpdx !== 'NOASSERTION')
  ) {
    findings.push(
      finding(
        'false_declared_license',
        'Declared-only status requires a declared SPDX id and repository NOASSERTION.',
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
  const requiredAssetTypes = Array.isArray(entry.artifactTypesReviewed)
    ? entry.artifactTypesReviewed.filter((value) => assetArtifactTypes.has(value))
    : [];
  const assetLicenseEvidence = Array.isArray(entry.artifactLicenseEvidence)
    ? entry.artifactLicenseEvidence
    : [];
  if (!Array.isArray(entry.artifactLicenseEvidence)) {
    findings.push(
      finding(
        'missing_artifact_license_evidence',
        'Artifact-level license evidence must be an array.',
        artifact,
      ),
    );
  }
  const reviewedAssetTypes = [];
  const scopedAssetPaths = [];
  for (const evidence of assetLicenseEvidence) {
    if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
      findings.push(
        finding(
          'invalid_artifact_license_evidence',
          'Artifact-level license evidence must be an object.',
          artifact,
        ),
      );
      continue;
    }
    if (!sameSet(Object.keys(evidence), artifactLicenseEvidenceKeys)) {
      findings.push(
        finding(
          'unsupported_artifact_license_evidence_shape',
          'Artifact-level license evidence has missing or unsupported fields.',
          artifact,
        ),
      );
    }
    if (!assetArtifactTypes.has(evidence.artifactType)) {
      findings.push(
        finding(
          'invalid_artifact_license_type',
          'Artifact-level license evidence is limited to model, data, report, terminology, and font assets.',
          artifact,
        ),
      );
    }
    reviewedAssetTypes.push(evidence.artifactType);
    if (
      ![
        'all_assets_of_type_at_pinned_revision',
        'transferred_files_at_pinned_revision',
      ].includes(evidence.assetScope)
    ) {
      findings.push(
        finding(
          'invalid_artifact_license_scope',
          'Artifact license scope must identify the complete category or exact transferred files at the pinned revision.',
          artifact,
        ),
      );
    }
    if (
      !spdxPattern.test(evidence.declaredSpdx ?? '') ||
      !spdxPattern.test(evidence.detectedSpdx ?? '')
    ) {
      findings.push(
        finding(
          'invalid_artifact_spdx',
          'Artifact-level license identity must be SPDX-like or NOASSERTION.',
          artifact,
        ),
      );
    }
    if (!licenseStatuses.has(evidence.licenseStatus)) {
      findings.push(
        finding(
          'invalid_artifact_license_status',
          'Artifact-level license status is unsupported.',
          artifact,
        ),
      );
    }
    if (!['reviewed', 'not_reviewed'].includes(evidence.reviewStatus)) {
      findings.push(
        finding(
          'invalid_artifact_review_status',
          'Artifact-level review status is unsupported.',
          artifact,
        ),
      );
    }
    if (
      evidence.licenseStatus === 'machine_detected' &&
      (evidence.declaredSpdx === 'NOASSERTION' ||
        evidence.detectedSpdx === 'NOASSERTION' ||
        evidence.declaredSpdx !== evidence.detectedSpdx)
    ) {
      findings.push(
        finding(
          'false_machine_detected_artifact_license',
          'Machine-detected artifact licenses must have matching SPDX evidence.',
          artifact,
        ),
      );
    }
    if (
      evidence.licenseStatus === 'unresolved' &&
      (evidence.declaredSpdx !== 'NOASSERTION' ||
        evidence.detectedSpdx !== 'NOASSERTION')
    ) {
      findings.push(
        finding(
          'false_unresolved_artifact_license',
          'Unresolved artifact licenses must remain NOASSERTION.',
          artifact,
        ),
      );
    }
    if (
      evidence.licenseStatus === 'declared_not_machine_detected' &&
      (evidence.declaredSpdx === 'NOASSERTION' ||
        evidence.detectedSpdx !== 'NOASSERTION')
    ) {
      findings.push(
        finding(
          'false_declared_artifact_license',
          'Declared-only artifact licenses require SPDX declaration and detected NOASSERTION.',
          artifact,
        ),
      );
    }
    if (
      evidence.reviewStatus === 'not_reviewed' &&
      evidence.licenseStatus !== 'unresolved'
    ) {
      findings.push(
        finding(
          'unreviewed_artifact_claims_license',
          'An unreviewed asset category must remain unresolved.',
          artifact,
        ),
      );
    }
    const expectedLocatorPrefix =
      typeof entry.officialUrl !== 'string'
        ? null
        : entry.officialUrl.startsWith('https://github.com/')
          ? `${entry.officialUrl}/tree/${entry.pinnedCommit}`
          : entry.officialUrl.startsWith('https://gitlab.com/')
            ? `${entry.officialUrl}/-/tree/${entry.pinnedCommit}`
            : `${entry.officialUrl}/src/${entry.pinnedCommit}`;
    if (
      !expectedLocatorPrefix ||
      typeof evidence.sourceLocator !== 'string' ||
      !(evidence.sourceLocator === expectedLocatorPrefix ||
        evidence.sourceLocator.startsWith(`${expectedLocatorPrefix}/`))
    ) {
      findings.push(
        finding(
          'unpinned_artifact_license_source',
          'Artifact-level license evidence must remain attached to its exact pinned source revision.',
          artifact,
        ),
      );
    }
    if (
      !Array.isArray(evidence.obligations) ||
      evidence.obligations.some((value) => typeof value !== 'string' || value.trim().length === 0) ||
      !evidence.obligations.every(
        (value, index) => index === 0 || evidence.obligations[index - 1].localeCompare(value) < 0,
      )
    ) {
      findings.push(
        finding(
          'invalid_artifact_license_obligations',
          'Artifact-level license obligations must be unique, sorted strings.',
          artifact,
        ),
      );
    }
    if (
      evidence.artifactType === 'font_asset' &&
      (!Array.isArray(evidence.obligations) ||
        !evidence.obligations.includes('license_notice') ||
        !evidence.obligations.includes('reserved_font_name_resolution'))
    ) {
      findings.push(
        finding(
          'missing_font_asset_obligation',
          'Transferred font assets require license notice and reserved-font-name review obligations.',
          artifact,
        ),
      );
    }
    if (!Array.isArray(evidence.localPaths)) {
      findings.push(
        finding(
          'invalid_artifact_local_paths',
          'Artifact-level local transfer paths must be an array.',
          artifact,
        ),
      );
    } else {
      const validPaths = evidence.localPaths.every((value, index) => {
        if (
          typeof value !== 'string' ||
          value.length === 0 ||
          path.isAbsolute(value) ||
          path.normalize(value) !== value ||
          value === '..' ||
          value.startsWith(`..${path.sep}`)
        ) {
          return false;
        }
        const previous = evidence.localPaths[index - 1];
        return index === 0 ||
          (typeof previous === 'string' && previous.localeCompare(value) < 0);
      });
      if (!validPaths) {
        findings.push(
          finding(
            'invalid_artifact_local_paths',
            'Artifact-level local transfer paths must be sorted and unique.',
            artifact,
          ),
        );
      }
      for (const localPath of evidence.localPaths) {
        if (typeof localPath !== 'string') continue;
        const resolvedPath = path.resolve(root, localPath);
        const relativePath = path.relative(root, resolvedPath);
        if (
          relativePath.startsWith('..') ||
          path.isAbsolute(relativePath) ||
          !existsSync(resolvedPath)
        ) {
          findings.push(
            finding(
              'missing_artifact_local_path',
              'Artifact-level local transfer path must exist inside the repository.',
              artifact,
            ),
          );
        }
        scopedAssetPaths.push(localPath);
      }
    }
  }
  if (
    new Set(reviewedAssetTypes).size !== reviewedAssetTypes.length ||
    !sameSet(requiredAssetTypes, reviewedAssetTypes)
  ) {
    findings.push(
      finding(
        'artifact_license_type_coverage_drift',
          'Every identified clinical-rule, data, model, report, terminology, and font asset category requires a separate license disposition.',
        artifact,
      ),
    );
  }
  const assetLicenseCoverageIncomplete =
    new Set(reviewedAssetTypes).size !== reviewedAssetTypes.length ||
    !sameSet(requiredAssetTypes, reviewedAssetTypes);
  const unresolvedAssetLicense =
    assetLicenseCoverageIncomplete ||
    assetLicenseEvidence.some(
      (evidence) =>
        evidence?.reviewStatus !== 'reviewed' ||
        evidence?.licenseStatus === 'unresolved',
    );
  if (new Set(scopedAssetPaths).size !== scopedAssetPaths.length) {
    findings.push(
      finding(
        'duplicate_artifact_local_path',
        'An upstream local transfer path cannot be attributed to multiple asset categories.',
        artifact,
      ),
    );
  }
  if (entry.transferStatus === 'concept_only' && scopedAssetPaths.length > 0) {
    findings.push(
      finding(
        'concept_only_boundary_violation',
        'Concept-only artifact evidence cannot claim local transferred assets.',
        artifact,
      ),
    );
  }
  if (entry.transferStatus !== 'concept_only' && unresolvedAssetLicense) {
    findings.push(
      finding(
        'unresolved_asset_license_transfer',
        'Transferred asset categories require separate resolved license evidence; repository-level SPDX is insufficient.',
        artifact,
      ),
    );
  }
  for (const key of ['localPaths', 'obligations']) {
    if (!Array.isArray(entry[key])) {
      findings.push(finding(`invalid_${key}`, `${key} must be an array.`, artifact));
    }
  }
  const localPaths = Array.isArray(entry.localPaths) ? entry.localPaths : [];
  const obligations = Array.isArray(entry.obligations) ? entry.obligations : [];
  if (
    entry.transferStatus !== 'concept_only' &&
    assetLicenseEvidence.length > 0 &&
    !sameSet(localPaths, scopedAssetPaths)
  ) {
    findings.push(
      finding(
        'unscoped_asset_transfer_path',
        'Every transferred local artifact path must be assigned to separately reviewed asset-level license evidence.',
        artifact,
      ),
    );
  }
  const isSortedUnique = (values) =>
    values.every(
        (value, index) => {
          const previous = values[index - 1];
          return typeof value === 'string' &&
            (index === 0 ||
              (typeof previous === 'string' && previous.localeCompare(value) < 0));
        },
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

  if (entry.transferStatus === 'development_linked') {
    if (entry.licenseStatus === 'unresolved') {
      findings.push(
        finding('unresolved_license_transfer', 'NOASSERTION cannot cross a dependency boundary.', artifact),
      );
    }
    if (
      entry.copyingAuthorized !== true ||
      entry.distributionAuthorized !== false ||
      localPaths.length === 0
    ) {
      findings.push(
        finding(
          'development_transfer_not_authorized',
          'Development-linked tools require copying authorization, no release distribution, and local lock paths.',
          artifact,
        ),
      );
    }
    if (releaseBoundary.developmentToolInfluenceIds?.includes(entry.id) !== true) {
      findings.push(
        finding(
          'development_boundary_omission',
          'Development-linked influence is absent from developmentToolInfluenceIds.',
          artifact,
        ),
      );
    }
    if (releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds?.includes(entry.id)) {
      findings.push(
        finding(
          'development_tool_in_release_boundary',
          'Development-only tools cannot be declared as release-linked influences.',
          artifact,
        ),
      );
    }
    for (const localPath of localPaths) {
      if (typeof localPath !== 'string' || !existsSync(path.join(root, localPath))) {
        findings.push(finding('missing_transferred_path', 'Development tool lock path is missing.', artifact));
      }
    }
    for (const obligation of ['dependency_lock', 'development_only', 'license_notice']) {
      if (!obligations.includes(obligation)) {
        findings.push(
          finding('missing_development_obligation', `Missing development-tool obligation: ${obligation}.`, artifact),
        );
      }
    }
    return;
  }

  if (!releaseTransferStatuses.has(entry.transferStatus)) return;

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
  if (
    (Array.isArray(entry.artifactTypesReviewed) &&
      entry.artifactTypesReviewed.includes('font_asset')) ||
    assetLicenseEvidence.some((evidence) => evidence?.artifactType === 'font_asset')
  ) {
    required.push('reserved_font_name_resolution');
  }
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
  if (inventory.$schema !== schemaUri || inventory.schemaVersion !== 7) {
    findings.push(finding('unsupported_schema', 'Expected influence inventory schema v7.'));
  }
  const review = inventory.review ?? {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(review.reviewedAt ?? '')) {
    findings.push(finding('invalid_review_date', 'reviewedAt must be YYYY-MM-DD.'));
  }
  if (!safeIdPattern.test(review.reviewerRole ?? '')) {
    findings.push(finding('invalid_reviewer_role', 'reviewerRole must be a safe identifier.'));
  }
  if (review.legalApproval !== 'not_requested_no_release_distribution') {
    findings.push(
      finding('unsupported_legal_approval', 'No release distribution or external legal approval is recorded.'),
    );
  }
  const releaseBoundary = inventory.releaseBoundary ?? {};
  for (const key of [
    'copiedLinkedVendoredOrDerivedInfluenceIds',
    'developmentToolInfluenceIds',
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
  const urls = influences.map((entry) => normalizeSourceRepository(entry?.officialUrl));
  if (new Set(ids).size !== ids.length) {
    findings.push(finding('duplicate_influence_id', 'Influence ids must be unique.'));
  }
  if (new Set(urls).size !== urls.length) {
    findings.push(finding('duplicate_influence_url', 'Influence repositories must be unique.'));
  }
  if (!ids.every((value, index) =>
    typeof value === 'string' &&
      (index === 0 ||
        (typeof ids[index - 1] === 'string' && ids[index - 1].localeCompare(value) < 0)))) {
    findings.push(finding('unsorted_influences', 'Influences must be sorted by id.'));
  }
  for (const entry of influences) validateEntry(entry, releaseBoundary, findings);
  validateAssetFileLicenseEvidence(inventory, findings);
  const releaseTransferIds = influences
    .filter((entry) => releaseTransferStatuses.has(entry.transferStatus))
    .map((entry) => entry.id);
  if (
    !sameSet(
      releaseTransferIds,
      releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds ?? [],
    )
  ) {
    findings.push(
      finding(
        'release_boundary_identity_drift',
        'Release-linked influence identities and releaseBoundary differ.',
      ),
    );
  }
  const developmentToolIds = influences
    .filter((entry) => entry.transferStatus === 'development_linked')
    .map((entry) => entry.id);
  if (!sameSet(developmentToolIds, releaseBoundary.developmentToolInfluenceIds ?? [])) {
    findings.push(
      finding(
        'development_boundary_identity_drift',
        'Development-linked influence identities and developmentToolInfluenceIds differ.',
      ),
    );
  }
  const linkedEvidenceIds = [...releaseTransferIds, ...developmentToolIds];
  const linkedVersionEvidence = releaseBoundary.linkedVersionEvidence ?? {};
  if (!sameSet(Object.keys(linkedVersionEvidence), linkedEvidenceIds)) {
    findings.push(
      finding(
        'linked_version_evidence_drift',
        'Every release or development-linked influence requires one exact linked-version record.',
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
  if (!sameSet(urls.filter(Boolean), observed.sourceRepositories ?? [])) {
    findings.push(
      finding(
        'influence_discovery_drift',
        'Documented source repositories and the reviewed inventory differ.',
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

function validateAssetFileLicenseEvidence(inventory, findings) {
  const records = inventory.assetFileLicenseEvidence;
  if (!Array.isArray(records)) {
    findings.push(
      finding(
        'missing_asset_file_license_evidence',
        'Every locally transferred asset path requires one file-level license record.',
      ),
    );
    return;
  }

  const ownersByPath = new Map();
  for (const influence of inventory.influences ?? []) {
    for (const evidence of influence?.artifactLicenseEvidence ?? []) {
      for (const assetPath of evidence?.localPaths ?? []) {
        if (typeof assetPath !== 'string') continue;
        const owners = ownersByPath.get(assetPath) ?? [];
        owners.push({ influence, evidence });
        ownersByPath.set(assetPath, owners);
      }
    }
  }

  const recordsByPath = new Map();
  let previousPath = null;
  const rootRealPath = realpathSync(root);
  for (const record of records) {
    if (!record || typeof record !== 'object' || Array.isArray(record)) {
      findings.push(
        finding(
          'invalid_asset_file_license_record',
          'File-level asset license records must be objects.',
        ),
      );
      continue;
    }
    const artifact = typeof record.assetPath === 'string' ? record.assetPath : null;
    if (!sameSet(Object.keys(record), assetFileLicenseEvidenceKeys)) {
      findings.push(
        finding(
          'unsupported_asset_file_license_record_shape',
          'File-level asset license record has missing or unsupported fields.',
          artifact,
        ),
      );
    }
    const assetPath = record.assetPath;
    if (
      typeof assetPath !== 'string' ||
      assetPath.length === 0 ||
      assetPath.includes('\\') ||
      assetPath.split('/').some((segment) => segment === '' || segment === '.' || segment === '..')
    ) {
      findings.push(
        finding(
          'invalid_asset_file_path',
          'Asset file paths must be normalized repository-relative paths.',
          artifact,
        ),
      );
      continue;
    }
    if (previousPath !== null && previousPath.localeCompare(assetPath) >= 0) {
      findings.push(
        finding(
          'unsorted_asset_file_license_records',
          'File-level asset license records must be uniquely sorted by path.',
          artifact,
        ),
      );
    }
    previousPath = assetPath;
    const duplicateRecords = recordsByPath.get(assetPath) ?? [];
    duplicateRecords.push(record);
    recordsByPath.set(assetPath, duplicateRecords);

    const resolvedPath = path.resolve(root, assetPath);
    const relativePath = path.relative(root, resolvedPath);
    if (
      relativePath.length === 0 ||
      relativePath === '..' ||
      relativePath.startsWith(`..${path.sep}`) ||
      path.isAbsolute(relativePath)
    ) {
      findings.push(
        finding(
          'asset_file_path_escapes_repository',
          'Asset file path resolves outside the repository.',
          artifact,
        ),
      );
      continue;
    }
    let bytes;
    try {
      const stat = lstatSync(resolvedPath);
      const resolvedRealPath = realpathSync(resolvedPath);
      const realRelativePath = path.relative(rootRealPath, resolvedRealPath);
      if (
        !stat.isFile() ||
        stat.isSymbolicLink() ||
        realRelativePath === '..' ||
        realRelativePath.startsWith(`..${path.sep}`) ||
        path.isAbsolute(realRelativePath)
      ) {
        throw new Error('asset is not a regular repository file');
      }
      bytes = readFileSync(resolvedPath);
    } catch {
      findings.push(
        finding(
          'missing_or_unsafe_asset_file',
          'Asset file must exist as a regular non-symlink file inside the repository.',
          artifact,
        ),
      );
      continue;
    }
    const observedDigest = createHash('sha256').update(bytes).digest('hex');
    if (!/^[0-9a-f]{64}$/.test(record.assetSha256 ?? '') || record.assetSha256 !== observedDigest) {
      findings.push(
        finding(
          'asset_file_digest_mismatch',
          'Asset file SHA-256 differs from its reviewed file-level record.',
          artifact,
        ),
      );
    }

    const owners = ownersByPath.get(assetPath) ?? [];
    if (owners.length !== 1) {
      findings.push(
        finding(
          'ambiguous_asset_file_license_owner',
          'Each asset path must map to exactly one artifact-level license record.',
          artifact,
        ),
      );
      continue;
    }
    const { influence, evidence } = owners[0];
    if (
      record.influenceId !== influence.id ||
      record.pinnedCommit !== influence.pinnedCommit ||
      record.artifactType !== evidence.artifactType ||
      record.declaredSpdx !== evidence.declaredSpdx ||
      record.detectedSpdx !== evidence.detectedSpdx ||
      record.licenseStatus !== evidence.licenseStatus ||
      record.reviewStatus !== evidence.reviewStatus ||
      record.sourceLocator !== evidence.sourceLocator ||
      evidence.artifactType !== 'font_asset' ||
      !sameSet(record.obligations, evidence.obligations)
    ) {
      findings.push(
        finding(
          'asset_file_license_source_mismatch',
          'File-level license identity must match its uniquely pinned and reviewed artifact record.',
          artifact,
        ),
      );
    }
    if (!['font_binary', 'license_text'].includes(record.assetRole)) {
      findings.push(
        finding(
          'invalid_asset_file_role',
          'Transferred font files must be classified as font_binary or license_text.',
          artifact,
        ),
      );
    }
    if (
      record.assetRole === 'font_binary' &&
      (!/\.(otf|ttf)$/i.test(assetPath) ||
        record.derivationStatus !== 'derived_static_font_source_equivalence_unverified' ||
        influence.transferStatus !== 'derived')
    ) {
      findings.push(
        finding(
          'invalid_derived_font_evidence',
          'Derived font outputs must retain the unverified source-equivalence boundary.',
          artifact,
        ),
      );
    }
    if (
      record.assetRole === 'license_text' &&
      (!/\.(txt|md|license)$/i.test(assetPath) ||
        record.derivationStatus !== 'copied_license_text_source_equivalence_unverified')
    ) {
      findings.push(
        finding(
          'invalid_license_text_evidence',
          'License-text files must retain their copied-source-equivalence boundary.',
          artifact,
        ),
      );
    }
    if (
      !Array.isArray(record.noticePaths) ||
      record.noticePaths.some((noticePath) => typeof noticePath !== 'string') ||
      new Set(record.noticePaths).size !== record.noticePaths.length
    ) {
      findings.push(
        finding(
          'invalid_asset_notice_paths',
          'Asset notice paths must be a unique string array.',
          artifact,
        ),
      );
    } else if (
      (record.assetRole === 'license_text' && record.noticePaths.length !== 0) ||
      (record.assetRole === 'font_binary' && record.noticePaths.length === 0)
    ) {
      findings.push(
        finding(
          'missing_asset_license_notice_path',
          'Each derived font output must point to its bundled license text.',
          artifact,
        ),
      );
    }
  }

  for (const [assetPath, owners] of ownersByPath) {
    if (owners.length !== 1) {
      findings.push(
        finding(
          'ambiguous_asset_file_license_owner',
          'Each transferred asset path must have exactly one pinned artifact-level license owner.',
          assetPath,
        ),
      );
    }
    if ((recordsByPath.get(assetPath) ?? []).length !== 1) {
      findings.push(
        finding(
          'asset_file_license_coverage_drift',
          'Each transferred asset file path must have exactly one file-level license record.',
          assetPath,
        ),
      );
    }
  }
  for (const [assetPath, pathRecords] of recordsByPath) {
    if (pathRecords.length !== 1) {
      findings.push(
        finding(
          'duplicate_asset_file_license_record',
          'An asset file path may have only one file-level license record.',
          assetPath,
        ),
      );
    }
    if (!ownersByPath.has(assetPath)) {
      findings.push(
        finding(
          'unassigned_asset_file_license_record',
          'A file-level license record must bind to one reviewed artifact-level asset path.',
          assetPath,
        ),
      );
    }
  }
  for (const record of records) {
    if (record?.assetRole !== 'font_binary' || !Array.isArray(record.noticePaths)) {
      continue;
    }
    for (const noticePath of record.noticePaths) {
      const notice = recordsByPath.get(noticePath) ?? [];
      if (
        notice.length !== 1 ||
        notice[0].assetRole !== 'license_text' ||
        notice[0].influenceId !== record.influenceId
      ) {
        findings.push(
          finding(
            'invalid_asset_license_notice_link',
            'Each font output notice must resolve to a file-level license text record for the same pinned influence.',
            record.assetPath,
          ),
        );
      }
    }
  }
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
  const unresolvedAssetEvidence = inventory.influences.flatMap(
    (entry) => entry.artifactLicenseEvidence ?? [],
  ).filter((entry) => entry.licenseStatus === 'unresolved').length;
  const releaseLinked = inventory.influences.filter((entry) =>
    releaseTransferStatuses.has(entry.transferStatus),
  ).length;
  const developmentLinked = inventory.influences.filter(
    (entry) => entry.transferStatus === 'development_linked',
  ).length;
  const derived = inventory.influences.filter(
    (entry) => entry.transferStatus === 'derived',
  ).length;
  console.log(
    `Open-source influence firewall passed: ${inventory.influences.length} pinned influences, ` +
      `${unresolved} unresolved licenses held concept-only, ${releaseLinked} release-linked influences, ` +
      `${unresolvedAssetEvidence} unresolved asset-license holds, ` +
      `${inventory.assetFileLicenseEvidence.length} path-level asset records, ` +
      `${developmentLinked} development-only linked ${developmentLinked === 1 ? 'tool' : 'tools'}, ` +
      `${derived} derived release-linked ${derived === 1 ? 'asset' : 'assets'}.`,
  );
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(runInfluenceCheck());
}
