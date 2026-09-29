#!/usr/bin/env node
// Human-authored, append-only review decisions for upstream drift proposals.
// Hash chaining detects edits against a retained chain anchor; it is not a
// signature and does not authenticate reviewer identity or establish approval.

import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const decisionLedgerSchemaUri =
  'parkinsum.open-source-drift-review-ledger/1';
export const reviewDecisionSchemaUri =
  'parkinsum.open-source-drift-review-decision/1';
const proposalSchemaUri =
  'https://parkinsum.app/schemas/open-source-drift-proposal/v1';
const zeroDigest = '0'.repeat(64);
const sha256Pattern = /^[0-9a-f]{64}$/;
const allowedDecisions = new Set([
  'accepted_for_baseline',
  'rejected',
  'deferred',
  'revoked',
]);
const allowedClassifications = new Set([
  'concept_only',
  'copied_or_derived_artifact',
  'linked_dependency',
  'vendored_artifact',
  'obligation_or_notice',
  'sbom_component',
  'scientific_model_or_data_claim',
  'no_material_change',
]);
const eventFields = [
  'sequence',
  'previousDigest',
  'proposalSha256',
  'inventorySha256',
  'influenceId',
  'officialUrl',
  'decision',
  'changeClassification',
  'reviewerIdentity',
  'reviewedAt',
  'rationale',
  'evidenceUrls',
  'digest',
];
const decisionFields = [
  '$schema',
  'schemaVersion',
  'proposalSha256',
  'inventorySha256',
  'influenceId',
  'officialUrl',
  'decision',
  'changeClassification',
  'reviewerIdentity',
  'reviewedAt',
  'rationale',
  'evidenceUrls',
];

function assertObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
}

function assertExactKeys(value, expected, label) {
  const keys = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(keys) !== JSON.stringify(wanted)) {
    throw new Error(`${label} has missing or unsupported fields`);
  }
}

function canonicalJson(value) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('Canonical JSON cannot encode a non-finite number');
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(',')}]`;
  }
  assertObject(value, 'Canonical JSON value');
  const members = Object.keys(value).sort().map((key) => {
    if (value[key] === undefined) throw new Error('Canonical JSON cannot encode undefined');
    return `${JSON.stringify(key)}:${canonicalJson(value[key])}`;
  });
  return `{${members.join(',')}}`;
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function utcTimestamp(value, label) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(value) ||
    !Number.isFinite(Date.parse(value))
  ) {
    throw new Error(`${label} must be a valid ISO UTC timestamp ending in Z`);
  }
  return Date.parse(value);
}

function safeEvidenceUrls(value) {
  if (!Array.isArray(value) || value.length > 20) {
    throw new Error('evidenceUrls must be an array with at most 20 URLs');
  }
  return value.map((raw) => {
    if (typeof raw !== 'string' || raw.length > 2048 || /[\u0000-\u001f]/.test(raw)) {
      throw new Error('evidenceUrls contains an invalid URL');
    }
    let url;
    try {
      url = new URL(raw);
    } catch {
      throw new Error('evidenceUrls contains an invalid URL');
    }
    if (url.protocol !== 'https:' || url.username || url.password) {
      throw new Error('evidenceUrls must use HTTPS and must not contain credentials');
    }
    return url.toString();
  });
}

function validateProposal(proposal) {
  assertObject(proposal, 'Proposal');
  if (
    proposal.$schema !== proposalSchemaUri ||
    proposal.schemaVersion !== 1 ||
    proposal.reportKind !== 'upstream_metadata_drift_proposal' ||
    !proposal.inventory ||
    !sha256Pattern.test(proposal.inventory.sha256 ?? '') ||
    !Array.isArray(proposal.proposals) ||
    proposal.proposals.length === 0
  ) {
    throw new Error('Unsupported or malformed upstream drift proposal');
  }
  const records = new Map();
  for (const record of proposal.proposals) {
    assertObject(record, 'Proposal source record');
    if (
      typeof record.influenceId !== 'string' ||
      !/^[a-z0-9][a-z0-9._:-]*$/.test(record.influenceId) ||
      records.has(record.influenceId) ||
      typeof record.officialUrl !== 'string'
    ) {
      throw new Error(`Malformed or duplicate proposal source: ${record.influenceId ?? '(missing id)'}`);
    }
    let officialUrl;
    try {
      officialUrl = new URL(record.officialUrl);
    } catch {
      throw new Error(`Proposal source URL is invalid for ${record.influenceId}`);
    }
    if (officialUrl.protocol !== 'https:' || officialUrl.username || officialUrl.password) {
      throw new Error(`Proposal source URL must be HTTPS for ${record.influenceId}`);
    }
    records.set(record.influenceId, record);
  }
  return records;
}

function blankReviewer() {
  return {
    decision: null,
    changeClassification: [],
    reviewerIdentity: null,
    reviewedAt: null,
    notes: null,
  };
}

function unsignedProposal(proposal) {
  const copy = structuredClone(proposal);
  for (const record of copy.proposals) record.reviewer = blankReviewer();
  return copy;
}

export function openSourceProposalSha256(proposal) {
  validateProposal(proposal);
  return sha256(canonicalJson(unsignedProposal(proposal)));
}

export function emptyOpenSourceDriftDecisionLedger() {
  return {
    $schema: decisionLedgerSchemaUri,
    schemaVersion: 1,
    events: [],
    tailDigest: zeroDigest,
  };
}

function eventBody(event) {
  const body = {};
  for (const key of eventFields) {
    if (key !== 'digest') body[key] = event[key];
  }
  return body;
}

function eventDigest(event) {
  return sha256(canonicalJson(eventBody(event)));
}

function validateEvent(event, index, previousDigest, previousTimestamp) {
  assertObject(event, `Ledger event ${index + 1}`);
  assertExactKeys(event, eventFields, `Ledger event ${index + 1}`);
  if (
    event.sequence !== index + 1 ||
    event.previousDigest !== previousDigest ||
    !sha256Pattern.test(event.proposalSha256 ?? '') ||
    !sha256Pattern.test(event.inventorySha256 ?? '') ||
    typeof event.influenceId !== 'string' ||
    !/^[a-z0-9][a-z0-9._:-]*$/.test(event.influenceId) ||
    typeof event.officialUrl !== 'string' ||
    !allowedDecisions.has(event.decision) ||
    !Array.isArray(event.changeClassification) ||
    new Set(event.changeClassification).size !== event.changeClassification.length ||
    event.changeClassification.some((item) => !allowedClassifications.has(item)) ||
    typeof event.reviewerIdentity !== 'string' ||
    event.reviewerIdentity.trim().length < 3 ||
    event.reviewerIdentity.length > 200 ||
    typeof event.rationale !== 'string' ||
    event.rationale.trim().length === 0 ||
    event.rationale.length > 2000 ||
    !sha256Pattern.test(event.digest ?? '')
  ) {
    throw new Error(`Ledger event ${index + 1} is malformed`);
  }
  let sourceUrl;
  try {
    sourceUrl = new URL(event.officialUrl);
  } catch {
    throw new Error(`Ledger event ${index + 1} has an invalid source URL`);
  }
  if (sourceUrl.protocol !== 'https:' || sourceUrl.username || sourceUrl.password) {
    throw new Error(`Ledger event ${index + 1} source URL must be HTTPS`);
  }
  if (event.decision !== 'revoked' && event.changeClassification.length === 0) {
    throw new Error(`Ledger event ${index + 1} must classify the reviewed change`);
  }
  const timestamp = utcTimestamp(event.reviewedAt, `Ledger event ${index + 1} reviewedAt`);
  if (previousTimestamp !== null && timestamp < previousTimestamp) {
    throw new Error(`Ledger event ${index + 1} timestamp precedes its predecessor`);
  }
  const evidence = safeEvidenceUrls(event.evidenceUrls);
  if (event.decision === 'accepted_for_baseline' && evidence.length === 0) {
    throw new Error(`Ledger event ${index + 1} needs at least one evidence URL`);
  }
  if (event.digest !== eventDigest(event)) {
    throw new Error(`Ledger event ${index + 1} digest mismatch`);
  }
  return { digest: event.digest, timestamp };
}

export function validateOpenSourceDriftDecisionLedger(ledger) {
  assertObject(ledger, 'Decision ledger');
  assertExactKeys(ledger, ['$schema', 'schemaVersion', 'events', 'tailDigest'], 'Decision ledger');
  if (
    ledger.$schema !== decisionLedgerSchemaUri ||
    ledger.schemaVersion !== 1 ||
    !Array.isArray(ledger.events) ||
    !sha256Pattern.test(ledger.tailDigest ?? '')
  ) {
    throw new Error('Unsupported or malformed upstream drift decision ledger');
  }
  let previousDigest = zeroDigest;
  let previousTimestamp = null;
  const sequenceByDigest = new Map([[zeroDigest, 0]]);
  for (const [index, event] of ledger.events.entries()) {
    const validated = validateEvent(event, index, previousDigest, previousTimestamp);
    previousDigest = validated.digest;
    previousTimestamp = validated.timestamp;
    sequenceByDigest.set(previousDigest, event.sequence);
  }
  if (ledger.tailDigest !== previousDigest) {
    throw new Error('Decision ledger tail digest does not match its append-only chain');
  }
  return { eventCount: ledger.events.length, tailDigest: previousDigest, sequenceByDigest };
}

function validateDecision(proposal, decision) {
  assertObject(decision, 'Review decision');
  assertExactKeys(decision, decisionFields, 'Review decision');
  const records = validateProposal(proposal);
  if (
    decision.$schema !== reviewDecisionSchemaUri ||
    decision.schemaVersion !== 1 ||
    decision.proposalSha256 !== openSourceProposalSha256(proposal) ||
    decision.inventorySha256 !== proposal.inventory.sha256 ||
    !records.has(decision.influenceId) ||
    records.get(decision.influenceId).officialUrl !== decision.officialUrl ||
    !allowedDecisions.has(decision.decision) ||
    !Array.isArray(decision.changeClassification) ||
    new Set(decision.changeClassification).size !== decision.changeClassification.length ||
    decision.changeClassification.some((item) => !allowedClassifications.has(item)) ||
    typeof decision.reviewerIdentity !== 'string' ||
    decision.reviewerIdentity.trim().length < 3 ||
    decision.reviewerIdentity.length > 200 ||
    typeof decision.rationale !== 'string' ||
    decision.rationale.trim().length === 0 ||
    decision.rationale.length > 2000
  ) {
    throw new Error('Review decision is malformed or does not match the proposal');
  }
  if (decision.decision !== 'revoked' && decision.changeClassification.length === 0) {
    throw new Error('Review decision must include a change classification');
  }
  const reviewedAt = utcTimestamp(decision.reviewedAt, 'Review decision reviewedAt');
  const evidenceUrls = safeEvidenceUrls(decision.evidenceUrls);
  if (decision.decision === 'accepted_for_baseline' && evidenceUrls.length === 0) {
    throw new Error('Accepted baseline decisions need at least one evidence URL');
  }
  return { reviewedAt, evidenceUrls };
}

export function appendOpenSourceDriftDecision({ proposal, decision, ledger = emptyOpenSourceDriftDecisionLedger() }) {
  const validatedLedger = validateOpenSourceDriftDecisionLedger(ledger);
  const validatedDecision = validateDecision(proposal, decision);
  const previousEvent = ledger.events.at(-1) ?? null;
  if (previousEvent && validatedDecision.reviewedAt < Date.parse(previousEvent.reviewedAt)) {
    throw new Error('Review decision timestamp precedes the current ledger tail');
  }
  const event = {
    sequence: validatedLedger.eventCount + 1,
    previousDigest: validatedLedger.tailDigest,
    proposalSha256: decision.proposalSha256,
    inventorySha256: decision.inventorySha256,
    influenceId: decision.influenceId,
    officialUrl: decision.officialUrl,
    decision: decision.decision,
    changeClassification: [...new Set(decision.changeClassification)].sort(),
    reviewerIdentity: decision.reviewerIdentity.trim(),
    reviewedAt: decision.reviewedAt,
    rationale: decision.rationale.trim(),
    evidenceUrls: validatedDecision.evidenceUrls,
  };
  event.digest = eventDigest(event);
  const next = {
    $schema: decisionLedgerSchemaUri,
    schemaVersion: 1,
    events: [...ledger.events, event],
    tailDigest: event.digest,
  };
  validateOpenSourceDriftDecisionLedger(next);
  return next;
}

function latestDecisions(ledger, proposalSha256, inventorySha256) {
  const latest = new Map();
  for (const event of ledger.events) {
    if (
      event.proposalSha256 === proposalSha256 &&
      event.inventorySha256 === inventorySha256
    ) {
      latest.set(event.influenceId, event);
    }
  }
  return latest;
}

export function projectAcceptedOpenSourceBaseline({ proposal, ledger }) {
  const records = validateProposal(proposal);
  const ledgerCheck = validateOpenSourceDriftDecisionLedger(ledger);
  const proposalSha256 = openSourceProposalSha256(proposal);
  const inventorySha256 = proposal.inventory.sha256;
  const latest = latestDecisions(ledger, proposalSha256, inventorySha256);
  for (const [influenceId, record] of records) {
    const event = latest.get(influenceId);
    if (!event || event.decision !== 'accepted_for_baseline') {
      throw new Error(`Latest review decision is missing or not accepted for ${influenceId}`);
    }
    if (event.officialUrl !== record.officialUrl) {
      throw new Error(`Latest review source identity does not match ${influenceId}`);
    }
  }
  if (latest.size !== records.size) {
    throw new Error('Review ledger contains proposal decisions outside the exact influence set');
  }
  const projected = structuredClone(proposal);
  for (const record of projected.proposals) {
    const event = latest.get(record.influenceId);
    record.reviewer = {
      decision: event.decision,
      changeClassification: [...event.changeClassification],
      reviewerIdentity: event.reviewerIdentity,
      reviewedAt: event.reviewedAt,
      notes: event.rationale,
      ledgerProof: {
        sequence: event.sequence,
        eventDigest: event.digest,
        anchorDigest: ledgerCheck.tailDigest,
      },
    };
  }
  const verified = validateAcceptedOpenSourceBaseline(projected, ledger);
  if (!verified.accepted) throw new Error(`Projected baseline failed validation: ${verified.status}`);
  return projected;
}

export function validateAcceptedOpenSourceBaseline(proposal, ledger) {
  let records;
  let ledgerCheck;
  try {
    records = validateProposal(proposal);
    ledgerCheck = validateOpenSourceDriftDecisionLedger(ledger);
  } catch (error) {
    return { accepted: false, status: 'decision_ledger_invalid', detail: error.message };
  }
  const proposalSha256 = openSourceProposalSha256(proposal);
  const inventorySha256 = proposal.inventory.sha256;
  const latest = latestDecisions(ledger, proposalSha256, inventorySha256);
  for (const [influenceId, record] of records) {
    const reviewer = record.reviewer;
    const event = latest.get(influenceId);
    if (!reviewer?.ledgerProof || !event) {
      return { accepted: false, status: 'human_decision_missing' };
    }
    try {
      assertExactKeys(
        reviewer,
        ['decision', 'changeClassification', 'reviewerIdentity', 'reviewedAt', 'notes', 'ledgerProof'],
        `Reviewer record for ${influenceId}`,
      );
      assertExactKeys(
        reviewer.ledgerProof,
        ['sequence', 'eventDigest', 'anchorDigest'],
        `Reviewer ledger proof for ${influenceId}`,
      );
    } catch {
      return { accepted: false, status: 'human_decision_ledger_mismatch' };
    }
    const anchorSequence = ledgerCheck.sequenceByDigest.get(reviewer.ledgerProof.anchorDigest);
    if (
      event.decision !== 'accepted_for_baseline' ||
      event.officialUrl !== record.officialUrl ||
      reviewer.decision !== event.decision ||
      JSON.stringify(reviewer.changeClassification) !== JSON.stringify(event.changeClassification) ||
      reviewer.reviewerIdentity !== event.reviewerIdentity ||
      reviewer.reviewedAt !== event.reviewedAt ||
      reviewer.notes !== event.rationale ||
      reviewer.ledgerProof.sequence !== event.sequence ||
      reviewer.ledgerProof.eventDigest !== event.digest ||
      anchorSequence === undefined ||
      anchorSequence < event.sequence
    ) {
      return { accepted: false, status: 'human_decision_ledger_mismatch' };
    }
  }
  if (latest.size !== records.size) {
    return { accepted: false, status: 'decision_influence_set_mismatch' };
  }
  return { accepted: true, status: 'reviewed_baseline', eventCount: ledgerCheck.eventCount };
}

function repositoryPath(relativePath, label) {
  if (path.isAbsolute(relativePath)) throw new Error(`${label} must be repository-relative`);
  const resolved = path.resolve(root, relativePath);
  if (!resolved.startsWith(`${root}${path.sep}`)) throw new Error(`${label} must stay inside the repository`);
  return resolved;
}

function readJson(relativePath, label) {
  const filePath = repositoryPath(relativePath, label);
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function writeNewJson(relativePath, value) {
  const outputPath = repositoryPath(relativePath, '--output');
  mkdirSync(path.dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
  return path.relative(root, outputPath);
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  if (!['append', 'project', 'template'].includes(command)) {
    if (command === '--help' || command === '-h' || command === undefined) return { help: true };
    throw new Error(`Unknown command: ${command}`);
  }
  const parsed = { command };
  for (let index = 0; index < rest.length; index += 1) {
    const flag = rest[index];
    if (!['--proposal', '--decision', '--ledger', '--output', '--influence'].includes(flag)) {
      throw new Error(`Unknown argument: ${flag}`);
    }
    const value = rest[index + 1];
    if (!value || value.startsWith('--')) throw new Error(`${flag} requires a value`);
    parsed[flag.slice(2)] = value;
    index += 1;
  }
  if (!parsed.proposal) throw new Error(`${command} requires --proposal`);
  if (command === 'append' && (!parsed.decision || !parsed.output)) {
    throw new Error('append requires --decision and --output');
  }
  if (command === 'project' && (!parsed.ledger || !parsed.output)) {
    throw new Error('project requires --ledger and --output');
  }
  if (command === 'template' && !parsed.influence) {
    throw new Error('template requires --influence');
  }
  return parsed;
}

function usage() {
  return [
    'Usage:',
    '  node tool/open_source_drift_decision_ledger.mjs template --proposal PATH --influence ID',
    '  node tool/open_source_drift_decision_ledger.mjs append --proposal PATH --decision PATH [--ledger PATH] --output NEW_PATH',
    '  node tool/open_source_drift_decision_ledger.mjs project --proposal PATH --ledger PATH --output NEW_PATH',
    'Each output requires a new path and refuses overwrite. The hash chain detects edits against retained digests, but does not authenticate reviewer identity or approve a release.',
    'Do not include patient information, credentials, or secrets in review rationale or evidence references.',
  ].join('\n');
}

function templateFor(proposal, influenceId) {
  const records = validateProposal(proposal);
  const record = records.get(influenceId);
  if (!record) throw new Error(`Influence is absent from proposal: ${influenceId}`);
  return {
    $schema: reviewDecisionSchemaUri,
    schemaVersion: 1,
    proposalSha256: openSourceProposalSha256(proposal),
    inventorySha256: proposal.inventory.sha256,
    influenceId,
    officialUrl: record.officialUrl,
    decision: 'deferred',
    changeClassification: [],
    reviewerIdentity: '',
    reviewedAt: '',
    rationale: '',
    evidenceUrls: [],
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  const proposal = readJson(args.proposal, '--proposal');
  if (args.command === 'template') {
    process.stdout.write(`${JSON.stringify(templateFor(proposal, args.influence), null, 2)}\n`);
    return;
  }
  if (args.command === 'append') {
    const decision = readJson(args.decision, '--decision');
    const ledger = args.ledger
      ? readJson(args.ledger, '--ledger')
      : emptyOpenSourceDriftDecisionLedger();
    const next = appendOpenSourceDriftDecision({ proposal, decision, ledger });
    process.stdout.write(`Decision appended: ${writeNewJson(args.output, next)} (${next.events.length} events).\n`);
    return;
  }
  const ledger = readJson(args.ledger, '--ledger');
  const projected = projectAcceptedOpenSourceBaseline({ proposal, ledger });
  process.stdout.write(`Reviewed baseline projected: ${writeNewJson(args.output, projected)}. This is not legal, clinical, or release approval.\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    main();
  } catch (error) {
    process.stderr.write(`${error?.message ?? 'Open-source decision ledger failed'}\n`);
    process.exitCode = 1;
  }
}
