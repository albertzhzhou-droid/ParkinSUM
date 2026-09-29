import test from 'node:test';
import assert from 'node:assert/strict';
import {
  appendOpenSourceDriftDecision,
  emptyOpenSourceDriftDecisionLedger,
  openSourceProposalSha256,
  projectAcceptedOpenSourceBaseline,
  validateAcceptedOpenSourceBaseline,
  validateOpenSourceDriftDecisionLedger,
  reviewDecisionSchemaUri,
} from './open_source_drift_decision_ledger.mjs';

const inventorySha = 'a'.repeat(64);
const reviewedAt = '2026-09-28T17:00:00.000Z';

function proposal() {
  return {
    $schema: 'https://parkinsum.app/schemas/open-source-drift-proposal/v1',
    schemaVersion: 1,
    reportKind: 'upstream_metadata_drift_proposal',
    releaseDecision: 'not_a_release_decision',
    reviewedAt,
    inventory: { schemaVersion: 7, sha256: inventorySha, influenceCount: 2 },
    previousProposal: { available: false, status: 'not_supplied' },
    collection: { mode: 'read_only_metadata_only', inventoryMutated: false },
    summary: { status: 'unverified', counts: { unverified: 2 } },
    proposals: [
      {
        influenceId: 'ahrq_cql_testing_framework',
        officialUrl: 'https://github.com/AHRQ-CDS/CQL-Testing-Framework',
        transferStatus: 'concept_only',
        observed: { pinnedCommit: '1'.repeat(40) },
        comparison: { status: 'unverified' },
        reviewer: {
          decision: null,
          changeClassification: [],
          reviewerIdentity: null,
          reviewedAt: null,
          notes: null,
        },
      },
      {
        influenceId: 'openclinical_proformajs_reference',
        officialUrl: 'https://gitlab.com/openclinical/proformajs',
        transferStatus: 'concept_only',
        observed: { pinnedCommit: '2'.repeat(40) },
        comparison: { status: 'unverified' },
        reviewer: {
          decision: null,
          changeClassification: [],
          reviewerIdentity: null,
          reviewedAt: null,
          notes: null,
        },
      },
    ],
  };
}

function decisionFor(report, influenceId, overrides = {}) {
  const record = report.proposals.find((entry) => entry.influenceId === influenceId);
  return {
    $schema: reviewDecisionSchemaUri,
    schemaVersion: 1,
    proposalSha256: openSourceProposalSha256(report),
    inventorySha256: report.inventory.sha256,
    influenceId,
    officialUrl: record.officialUrl,
    decision: 'accepted_for_baseline',
    changeClassification: ['no_material_change'],
    reviewerIdentity: 'reviewer@example.test',
    reviewedAt,
    rationale: `Fixture review for ${influenceId}; not a legal or clinical determination.`,
    evidenceUrls: [record.officialUrl],
    ...overrides,
  };
}

function acceptAll(report) {
  let ledger = emptyOpenSourceDriftDecisionLedger();
  for (const record of report.proposals) {
    ledger = appendOpenSourceDriftDecision({
      proposal: report,
      decision: decisionFor(report, record.influenceId),
      ledger,
    });
  }
  return ledger;
}

test('decision events form a sequential hash chain bound to proposal and inventory digests', () => {
  const report = proposal();
  let ledger = emptyOpenSourceDriftDecisionLedger();
  ledger = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[0].influenceId),
    ledger,
  });
  const prefix = structuredClone(ledger);
  ledger = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[1].influenceId),
    ledger,
  });

  assert.equal(ledger.events.length, 2);
  assert.equal(ledger.events[0].sequence, 1);
  assert.equal(ledger.events[1].sequence, 2);
  assert.equal(ledger.events[1].previousDigest, prefix.tailDigest);
  assert.equal(ledger.tailDigest, ledger.events[1].digest);
  assert.equal(validateOpenSourceDriftDecisionLedger(ledger).eventCount, 2);
});

test('accepted decisions project only when every exact source has a latest accepted event', () => {
  const report = proposal();
  let ledger = acceptAll(report);
  const baseline = projectAcceptedOpenSourceBaseline({ proposal: report, ledger });
  const validation = validateAcceptedOpenSourceBaseline(baseline, ledger);
  assert.equal(validation.accepted, true);
  assert.equal(validation.status, 'reviewed_baseline');
  assert.equal(baseline.proposals[0].reviewer.decision, 'accepted_for_baseline');
  assert.equal(baseline.proposals[0].reviewer.ledgerProof.eventDigest, ledger.events[0].digest);

  ledger = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[0].influenceId, {
      decision: 'revoked',
      changeClassification: [],
      reviewedAt: '2026-09-28T17:01:00.000Z',
      rationale: 'The acceptance was withdrawn pending additional source review.',
      evidenceUrls: [],
    }),
    ledger,
  });
  assert.throws(
    () => projectAcceptedOpenSourceBaseline({ proposal: report, ledger }),
    /Latest review decision is missing or not accepted/,
  );
  assert.equal(
    validateAcceptedOpenSourceBaseline(baseline, ledger).status,
    'human_decision_ledger_mismatch',
  );
});

test('unreviewed, deferred, and partial reviews cannot become a baseline', () => {
  const report = proposal();
  const oneDecision = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[0].influenceId),
  });
  assert.throws(
    () => projectAcceptedOpenSourceBaseline({ proposal: report, ledger: oneDecision }),
    /Latest review decision is missing or not accepted for openclinical/,
  );
  const deferred = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[0].influenceId, {
      decision: 'deferred',
      reviewedAt: '2026-09-28T17:01:00.000Z',
    }),
    ledger: oneDecision,
  });
  assert.throws(
    () => projectAcceptedOpenSourceBaseline({ proposal: report, ledger: deferred }),
    /Latest review decision is missing or not accepted/,
  );
});

test('ledger detects event, order, tail, and retained-anchor mutations', () => {
  const report = proposal();
  const ledger = acceptAll(report);
  const tampered = structuredClone(ledger);
  tampered.events[0].rationale = 'Changed after review';
  assert.throws(() => validateOpenSourceDriftDecisionLedger(tampered), /digest mismatch/);

  const reordered = structuredClone(ledger);
  [reordered.events[0], reordered.events[1]] = [reordered.events[1], reordered.events[0]];
  assert.throws(() => validateOpenSourceDriftDecisionLedger(reordered), /malformed|predecessor/);

  const truncated = { ...ledger, events: ledger.events.slice(0, 1) };
  assert.throws(() => validateOpenSourceDriftDecisionLedger(truncated), /tail digest/);

  const baseline = projectAcceptedOpenSourceBaseline({ proposal: report, ledger });
  const missingAnchor = { ...ledger, events: ledger.events.slice(1) };
  assert.equal(
    validateAcceptedOpenSourceBaseline(baseline, missingAnchor).status,
    'decision_ledger_invalid',
  );
});

test('review inputs reject mismatched pins, unsafe evidence URLs, and bad chronology', () => {
  const report = proposal();
  const wrongDigest = decisionFor(report, report.proposals[0].influenceId, {
    proposalSha256: 'f'.repeat(64),
  });
  assert.throws(() => appendOpenSourceDriftDecision({ proposal: report, decision: wrongDigest }), /malformed or does not match/);

  const unsafeEvidence = decisionFor(report, report.proposals[0].influenceId, {
    evidenceUrls: ['http://example.test/review'],
  });
  assert.throws(() => appendOpenSourceDriftDecision({ proposal: report, decision: unsafeEvidence }), /HTTPS/);

  const accepted = appendOpenSourceDriftDecision({
    proposal: report,
    decision: decisionFor(report, report.proposals[0].influenceId),
  });
  const earlier = decisionFor(report, report.proposals[1].influenceId, {
    reviewedAt: '2026-09-28T16:59:59.000Z',
  });
  assert.throws(
    () => appendOpenSourceDriftDecision({ proposal: report, decision: earlier, ledger: accepted }),
    /precedes the current ledger tail/,
  );
});

test('reviewer annotations are bound to the ledger and cannot be edited independently', () => {
  const report = proposal();
  const ledger = acceptAll(report);
  const baseline = projectAcceptedOpenSourceBaseline({ proposal: report, ledger });
  const edited = structuredClone(baseline);
  edited.proposals[0].reviewer.notes = 'Changed outside the review ledger';
  assert.equal(
    validateAcceptedOpenSourceBaseline(edited, ledger).status,
    'human_decision_ledger_mismatch',
  );
});
