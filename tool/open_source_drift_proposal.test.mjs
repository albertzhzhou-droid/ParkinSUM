import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { collectOpenSourceDriftProposal } from './open_source_drift_proposal.mjs';
import {
  appendOpenSourceDriftDecision,
  emptyOpenSourceDriftDecisionLedger,
  openSourceProposalSha256,
  projectAcceptedOpenSourceBaseline,
  reviewDecisionSchemaUri,
} from './open_source_drift_decision_ledger.mjs';

const sha = (digit) => digit.repeat(40);
const reviewedAt = '2026-09-28T16:00:00.000Z';
const grevaluatorPin = '769ad73ae6e715d989c652fed9f8bd9b66206cf4';

function entry({
  id = 'ahrq_cql_testing_framework',
  officialUrl = 'https://github.com/AHRQ-CDS/CQL-Testing-Framework',
  pinnedCommit = sha('1'),
  defaultBranch = 'master',
  declaredSpdx = 'Apache-2.0',
  repositoryDetectedSpdx = 'Apache-2.0',
  licenseStatus = 'machine_detected',
  transferStatus = 'concept_only',
} = {}) {
  return {
    id,
    officialUrl,
    pinnedCommit,
    defaultBranch,
    declaredSpdx,
    repositoryDetectedSpdx,
    transferStatus,
    licenseStatus,
  };
}

function inventory(influences = [entry()]) {
  return {
    $schema: 'https://parkinsum.app/schemas/open-source-influence-inventory/v7',
    schemaVersion: 7,
    influences,
  };
}

function acceptAsBaseline(report) {
  let ledger = emptyOpenSourceDriftDecisionLedger();
  for (const proposal of report.proposals) {
    ledger = appendOpenSourceDriftDecision({
      proposal: report,
      decision: {
        $schema: reviewDecisionSchemaUri,
        schemaVersion: 1,
        proposalSha256: openSourceProposalSha256(report),
        inventorySha256: report.inventory.sha256,
        influenceId: proposal.influenceId,
        officialUrl: proposal.officialUrl,
        decision: 'accepted_for_baseline',
        changeClassification: ['no_material_change'],
        reviewerIdentity: 'reviewer@example.test',
        reviewedAt,
        rationale: 'Fixture-only reviewer decision for the contract test.',
        evidenceUrls: [proposal.officialUrl],
      },
      ledger,
    });
  }
  return {
    proposal: projectAcceptedOpenSourceBaseline({ proposal: report, ledger }),
    ledger,
  };
}

function response(body, { status = 200, headers = {} } = {}) {
  return {
    status,
    ok: status >= 200 && status < 300,
    headers: new Headers(headers),
    async text() { return typeof body === 'string' ? body : JSON.stringify(body); },
  };
}

function githubFetch({ tagAtPin = true, statusOverrides = {} } = {}) {
  return async (rawUrl, init) => {
    const url = new URL(rawUrl);
    const pathname = url.pathname.toLowerCase();
    assert.equal(init.method, 'GET');
    assert.equal(init.redirect, 'manual');
    assert.equal(init.headers['x-github-api-version'], '2026-03-10');
    if (statusOverrides[url.pathname]) return response({ message: 'rate limited' }, { status: statusOverrides[url.pathname] });
    if (pathname === '/repos/ahrq-cds/cql-testing-framework') {
      return response({
        full_name: 'AHRQ-CDS/CQL-Testing-Framework',
        html_url: 'https://github.com/AHRQ-CDS/CQL-Testing-Framework',
        default_branch: 'master',
        archived: false,
        license: { spdx_id: 'Apache-2.0', key: 'apache-2.0' },
      }, { headers: { 'x-ratelimit-remaining': '4998' } });
    }
    if (pathname === '/repos/ceosys/grevaluator') {
      return response({
        full_name: 'CEOsys/grevaluator',
        html_url: 'https://github.com/CEOsys/grevaluator',
        default_branch: 'master',
        archived: false,
        license: { spdx_id: 'AGPL-3.0', key: 'agpl-3.0' },
      });
    }
    if (pathname.endsWith(`/git/commits/${sha('1')}`)) return response({ sha: sha('1'), parents: [] });
    if (pathname.endsWith('/git/ref/heads/master')) {
      return response({ ref: 'refs/heads/master', object: { type: 'commit', sha: sha('2') } });
    }
    if (pathname.endsWith(`/git/commits/${sha('2')}`)) {
      return response({ sha: sha('2'), parents: [{ sha: sha('1') }] });
    }
    if (pathname.endsWith(`/git/commits/${grevaluatorPin}`)) {
      return response({ sha: grevaluatorPin, parents: [] });
    }
    if (pathname.endsWith('/git/ref/heads/master') && pathname.startsWith('/repos/ceosys/grevaluator/')) {
      return response({ ref: 'refs/heads/master', object: { type: 'commit', sha: sha('c') } });
    }
    if (pathname.endsWith(`/git/commits/${sha('c')}`)) {
      return response({ sha: sha('c'), parents: [{ sha: grevaluatorPin }] });
    }
    if (pathname.endsWith('/tags')) {
      if (url.searchParams.get('page') === '1') {
        return response([
          { name: 'v1.0', commit: { sha: tagAtPin ? sha('1') : sha('3') } },
        ], {
          headers: {
            link: `<https://api.github.com${url.pathname}?per_page=100&page=2>; rel="next"`,
          },
        });
      }
      if (url.searchParams.get('page') === '2') {
        return response([{ name: 'v0.9', commit: { sha: sha('4') } }]);
      }
    }
    throw new Error(`Unexpected GitHub URL: ${url}`);
  };
}

function gitlabFetch() {
  return async (rawUrl) => {
    const url = new URL(rawUrl);
    const base = '/api/v4/projects/openclinical%2Fproformajs';
    if (url.pathname === base) {
      return response({
        id: 42,
        path_with_namespace: 'openclinical/proformajs',
        web_url: 'https://gitlab.com/openclinical/proformajs',
        default_branch: 'main',
        archived: false,
        license: { key: 'gpl-3.0', spdx_id: 'GPL-3.0' },
      });
    }
    if (url.pathname === `${base}/repository/commits/${sha('5')}`) return response({ id: sha('5') });
    if (url.pathname === `${base}/repository/commits/main`) return response({ id: sha('6') });
    if (url.pathname === `${base}/repository/tags` && url.searchParams.get('page') === '1') {
      return response([{ name: 'v0.1.0', commit: { id: sha('5') } }], {
        headers: { 'x-next-page': '2' },
      });
    }
    if (url.pathname === `${base}/repository/tags` && url.searchParams.get('page') === '2') {
      return response([{ name: 'older', commit: { id: sha('7') } }]);
    }
    throw new Error(`Unexpected GitLab URL: ${url}`);
  };
}

function bitbucketFetch() {
  return async (rawUrl) => {
    const url = new URL(rawUrl);
    const base = '/2.0/repositories/opencds/opencds';
    if (url.pathname === base) {
      return response({
        full_name: 'opencds/opencds',
        mainbranch: { name: 'master' },
        links: { html: { href: 'https://bitbucket.org/opencds/opencds' } },
      });
    }
    if (url.pathname === `${base}/commit/${sha('8')}`) return response({ hash: sha('8') });
    if (url.pathname === `${base}/commits/master`) return response({ values: [{ hash: sha('9') }] });
    if (url.pathname === `${base}/refs/tags`) {
      if (!url.searchParams.has('page')) {
        return response({
          values: [{ name: 'core-v1', target: { type: 'commit', hash: sha('8') } }],
          next: 'https://api.bitbucket.org/2.0/repositories/opencds/opencds/refs/tags?pagelen=100&page=2',
        });
      }
      return response({ values: [{ name: 'old', target: { type: 'commit', hash: sha('a') } }] });
    }
    throw new Error(`Unexpected Bitbucket URL: ${url}`);
  };
}

test('GitHub proposal captures pin, branch, history, all tag pages, API and rate evidence', async () => {
  const currentInventory = inventory();
  const raw = JSON.stringify(currentInventory);
  const report = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: raw,
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  const [proposal] = report.proposals;
  assert.ok(proposal.observed, JSON.stringify(proposal.retrieval));
  assert.equal(report.$schema, 'https://parkinsum.app/schemas/open-source-drift-proposal/v1');
  assert.equal(report.releaseDecision, 'not_a_release_decision');
  assert.equal(report.collection.inventoryMutated, false);
  assert.equal(report.collection.sourceTreeDownloaded, false);
  assert.equal(report.summary.status, 'unverified');
  assert.equal(proposal.observed.repositoryIdentity, 'github.com/ahrq-cds/cql-testing-framework');
  assert.equal(proposal.observed.pinnedCommit, sha('1'));
  assert.equal(proposal.observed.defaultBranchHead, sha('2'));
  assert.equal(proposal.observed.historyRelation, 'ahead');
  assert.deepEqual(proposal.observed.releaseOrTagIdentity.refsAtPinnedCommit, [
    { name: 'v1.0', commit: sha('1') },
  ]);
  assert.equal(proposal.observed.tagsPagination.pages, 2);
  assert.equal(proposal.observed.license.detectedSpdx, 'Apache-2.0');
  assert.equal(proposal.observed.license.declaredSpdx, 'NOASSERTION');
  assert.equal(proposal.previous.releaseOrTagIdentity.status, 'not_recorded_in_inventory');
  assert.ok(proposal.retrieval.requests.every((request) => request.apiVersion === '2026-03-10'));
  assert.equal(proposal.retrieval.rateLimitStatus, 'available');
  assert.ok(proposal.retrieval.requests.every((request) => !request.request.includes('/compare/')));
  assert.equal(proposal.retrieval.requests.filter((request) => request.kind === 'history_commit_object').length, 1);
  assert.ok(proposal.comparison.unverifiedCodes.includes('no_prior_drift_snapshot'));
  assert.equal(JSON.stringify(proposal).includes('patch'), false);
  assert.equal(JSON.stringify(currentInventory), raw);
});

test('GitLab and Bitbucket adapters record provider version, archive, tag, and unknown-license limits', async () => {
  const currentInventory = inventory([
    entry({
      id: 'openclinical_proformajs_reference',
      officialUrl: 'https://gitlab.com/openclinical/proformajs',
      pinnedCommit: sha('5'),
      defaultBranch: 'main',
      declaredSpdx: 'GPL-3.0',
      repositoryDetectedSpdx: 'NOASSERTION',
      licenseStatus: 'declared_not_machine_detected',
      transferStatus: 'concept_only',
    }),
    entry({
      id: 'opencds_core_reference',
      officialUrl: 'https://bitbucket.org/opencds/opencds',
      pinnedCommit: sha('8'),
      defaultBranch: 'master',
      declaredSpdx: 'Apache-2.0',
      repositoryDetectedSpdx: 'NOASSERTION',
      licenseStatus: 'declared_not_machine_detected',
      transferStatus: 'concept_only',
    }),
  ]);
  const report = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl: async (url, init) => {
      const host = new URL(url).hostname;
      return host === 'gitlab.com' ? gitlabFetch()(url, init) : bitbucketFetch()(url, init);
    },
  });
  const [gitlab, bitbucket] = report.proposals;
  assert.equal(gitlab.observed.apiVersion, 'GitLab REST API v4');
  assert.equal(gitlab.observed.archived, false);
  assert.equal(gitlab.observed.releaseOrTagIdentity.refsAtPinnedCommit[0].name, 'v0.1.0');
  assert.equal(gitlab.observed.tagsPagination.pages, 2);
  assert.equal(gitlab.observed.license.detectedSpdx, 'GPL-3.0');
  assert.equal(gitlab.observed.historyRelation, 'unverified_provider_comparison_not_yet_supported');
  assert.ok(gitlab.comparison.unverifiedCodes.includes('history_relation_unverified'));
  assert.equal(bitbucket.observed.apiVersion, 'Bitbucket Cloud REST API 2.0');
  assert.equal(bitbucket.observed.archived, null);
  assert.equal(bitbucket.observed.license.detectedSpdx, 'NOASSERTION');
  assert.equal(bitbucket.observed.tagsPagination.pages, 2);
  assert.ok(bitbucket.comparison.unverifiedCodes.includes('archive_state_unavailable'));
  assert.ok(bitbucket.comparison.unverifiedCodes.includes('detected_license_noassertion'));
});

test('an archived repository, identity change, non-ancestor pin, or tag movement blocks the proposal', async () => {
  const currentInventory = inventory();
  const first = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  const changedFetch = async (rawUrl, init) => {
    const url = new URL(rawUrl);
    const pathname = url.pathname.toLowerCase();
    if (pathname === '/repos/ahrq-cds/cql-testing-framework') {
      return response({
        full_name: 'moved/CQL-Testing-Framework',
        html_url: ['https://github.com', '/moved/CQL-Testing-Framework'].join(''),
        default_branch: 'main',
        archived: true,
        license: { spdx_id: 'GPL-3.0', key: 'gpl-3.0' },
      });
    }
    if (pathname.endsWith(`/git/commits/${sha('1')}`)) return response({ sha: sha('1'), parents: [] });
    if (pathname.endsWith('/git/ref/heads/main')) {
      return response({ ref: 'refs/heads/main', object: { type: 'commit', sha: sha('2') } });
    }
    if (pathname.endsWith(`/git/commits/${sha('2')}`)) {
      return response({ sha: sha('2'), parents: [{ sha: sha('3') }] });
    }
    if (pathname.endsWith(`/git/commits/${sha('3')}`)) {
      return response({ sha: sha('3'), parents: [] });
    }
    if (pathname.endsWith('/tags')) return response([]);
    return githubFetch()(rawUrl, init);
  };
  const baseline = acceptAsBaseline(first);
  const second = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    previousProposal: baseline.proposal,
    previousDecisionLedger: baseline.ledger,
    reviewedAt: '2026-09-29T16:00:00.000Z',
    fetchImpl: changedFetch,
  });
  const proposal = second.proposals[0];
  assert.equal(proposal.comparison.status, 'blocker');
  assert.ok(proposal.comparison.blockerCodes.includes('repository_identity_changed'));
  assert.ok(proposal.comparison.blockerCodes.includes('repository_archived'));
  assert.ok(proposal.comparison.blockerCodes.includes('history_relation_changed'));
  assert.ok(proposal.comparison.blockerCodes.includes('detected_license_changed_from_inventory'));
  assert.ok(proposal.comparison.blockerCodes.includes('tag_identity_changed'));
});

test('rate limits and missing commits are represented as unverified and do not abort other sources', async () => {
  const currentInventory = inventory([
    entry(),
    entry({
      id: 'grevaluator_guideline_recommendation_evaluator',
      officialUrl: 'https://github.com/CEOsys/grevaluator',
      pinnedCommit: grevaluatorPin,
      defaultBranch: 'master',
      declaredSpdx: 'AGPL-3.0',
      repositoryDetectedSpdx: 'AGPL-3.0',
    }),
  ]);
  let rateLimitedOnce = false;
  const fetchImpl = async (url, init) => {
    const parsed = new URL(url);
    if (parsed.pathname.toLowerCase() === '/repos/ahrq-cds/cql-testing-framework' && !rateLimitedOnce) {
      rateLimitedOnce = true;
      return response({ message: 'API rate limit exceeded' }, {
        status: 403,
        headers: { 'x-ratelimit-remaining': '0', 'retry-after': '60' },
      });
    }
    return githubFetch()(url, init);
  };
  const report = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl,
  });
  assert.equal(report.proposals[0].comparison.status, 'unverified');
  assert.equal(report.proposals[0].retrieval.failure.code, 'rate_limited_or_forbidden');
  assert.equal(report.proposals[0].retrieval.rateLimitStatus, 'limited_or_retry_after');
  assert.equal(report.proposals[1].observed.pinnedCommit, grevaluatorPin);
  assert.equal(report.proposals.length, 2);
});

test('redirects and unsafe pagination are not followed', async () => {
  const currentInventory = inventory();
  const redirected = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl: async () => response('', {
      status: 301,
      headers: { location: ['https://github.com', '/new-owner/new-name'].join('') },
    }),
  });
  assert.equal(redirected.proposals[0].comparison.status, 'blocker');
  assert.equal(redirected.proposals[0].retrieval.failure.code, 'repository_redirected');
  assert.equal(redirected.proposals[0].retrieval.requests[0].redirectTarget, 'github.com/new-owner/new-name');

  const paginationAttack = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl: async (rawUrl) => {
      const url = new URL(rawUrl);
      if (url.pathname.toLowerCase() === '/repos/ahrq-cds/cql-testing-framework') {
        return response({ full_name: 'AHRQ-CDS/CQL-Testing-Framework', html_url: 'https://github.com/AHRQ-CDS/CQL-Testing-Framework', default_branch: 'master', archived: false, license: { spdx_id: 'Apache-2.0' } });
      }
      if (url.pathname.toLowerCase().endsWith(`/git/commits/${sha('1')}`)) return response({ sha: sha('1'), parents: [] });
      if (url.pathname.toLowerCase().endsWith('/git/ref/heads/master')) {
        return response({ ref: 'refs/heads/master', object: { type: 'commit', sha: sha('2') } });
      }
      if (url.pathname.toLowerCase().endsWith(`/git/commits/${sha('2')}`)) {
        return response({ sha: sha('2'), parents: [{ sha: sha('1') }] });
      }
      if (url.pathname.endsWith('/tags')) return response([], {
        headers: { link: '<https://attacker.invalid/steal?page=2>; rel="next"' },
      });
      throw new Error(`Unexpected URL: ${url}`);
    },
  });
  assert.equal(paginationAttack.proposals[0].comparison.status, 'unverified');
  assert.equal(paginationAttack.proposals[0].retrieval.failure.code, 'pagination_target_rejected');
});

test('missing pins and tag-page limits stay unverified rather than passing', async () => {
  const currentInventory = inventory();
  const missingPin = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    fetchImpl: async (rawUrl, init) => {
      if (new URL(rawUrl).pathname.endsWith(`/git/commits/${sha('1')}`)) {
        return response({ message: 'commit not found' }, { status: 404 });
      }
      return githubFetch()(rawUrl, init);
    },
  });
  assert.equal(missingPin.proposals[0].retrieval.failure.code, 'not_found');
  assert.equal(missingPin.proposals[0].comparison.status, 'unverified');
  assert.ok(missingPin.proposals[0].retrieval.requests.some((request) => request.kind === 'pinned_commit'));

  const incompleteTags = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    reviewedAt,
    maxTagPages: 1,
    fetchImpl: githubFetch(),
  });
  assert.equal(incompleteTags.proposals[0].retrieval.failure.code, 'pagination_incomplete');
  assert.equal(incompleteTags.proposals[0].comparison.status, 'unverified');
});

test('malformed or mismatched inventories and prior proposals fail closed', async () => {
  await assert.rejects(
    collectOpenSourceDriftProposal({ inventory: { schemaVersion: 6, influences: [] } }),
    /Unsupported or malformed/,
  );
  const currentInventory = inventory();
  const invalidPrevious = {
    $schema: 'https://parkinsum.app/schemas/open-source-drift-proposal/v1',
    schemaVersion: 1,
    inventory: { sha256: '0'.repeat(64) },
    proposals: [],
  };
  const report = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    previousProposal: invalidPrevious,
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  assert.equal(report.previousProposal.available, false);
  assert.equal(report.summary.status, 'unverified');
  assert.ok(report.proposals[0].comparison.unverifiedCodes.includes('previous_proposal_inventory_digest_mismatch'));

  const unreviewedBaseline = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    previousProposal: report,
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  assert.equal(unreviewedBaseline.previousProposal.available, false);
  assert.equal(unreviewedBaseline.previousProposal.status, 'previous_proposal_decision_ledger_missing');
  assert.ok(unreviewedBaseline.proposals[0].comparison.unverifiedCodes.includes('previous_proposal_decision_ledger_missing'));

  const acceptedButDetached = acceptAsBaseline(report);
  const detachedBaseline = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    previousProposal: acceptedButDetached.proposal,
    previousDecisionLedger: emptyOpenSourceDriftDecisionLedger(),
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  assert.equal(detachedBaseline.previousProposal.available, false);
  assert.equal(detachedBaseline.previousProposal.status, 'previous_proposal_human_decision_missing');

  const changedLedger = structuredClone(acceptedButDetached.ledger);
  changedLedger.events[0].rationale = 'edited after the review';
  const tamperedBaseline = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText: JSON.stringify(currentInventory),
    previousProposal: acceptedButDetached.proposal,
    previousDecisionLedger: changedLedger,
    reviewedAt,
    fetchImpl: githubFetch(),
  });
  assert.equal(tamperedBaseline.previousProposal.available, false);
  assert.equal(tamperedBaseline.previousProposal.status, 'previous_proposal_decision_ledger_invalid');
});

test('current 93-source inventory yields one isolated record per source during API failure', async () => {
  const inventoryUrl = new URL('../config/open_source_influence_inventory.json', import.meta.url);
  const inventoryText = readFileSync(inventoryUrl, 'utf8');
  const currentInventory = JSON.parse(inventoryText);
  const report = await collectOpenSourceDriftProposal({
    inventory: currentInventory,
    inventoryText,
    reviewedAt,
    fetchImpl: async () => response({ message: 'rate limited' }, { status: 429, headers: { 'retry-after': '30' } }),
  });
  assert.equal(report.inventory.influenceCount, currentInventory.influences.length);
  assert.equal(report.proposals.length, currentInventory.influences.length);
  assert.equal(report.summary.status, 'unverified');
  assert.equal(report.summary.counts.unverified, currentInventory.influences.length);
  assert.ok(report.proposals.every((proposal) => proposal.retrieval.failure?.code === 'rate_limited_or_forbidden'));
  assert.ok(report.proposals.every((proposal) => proposal.observed === null));
  assert.ok(report.proposals.every((proposal) => proposal.reviewer.decision === null));
});
