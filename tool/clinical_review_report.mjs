#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const releaseId = args['release-id'] ?? `clinical_review_${timestamp()}`;
const reviewerStatus = args['reviewer-status'] ?? 'pending clinical/domain review';
const reviewer = args.reviewer ?? 'pending reviewer';
const output =
  args.output ??
  path.join('build', 'clinical_review', `${releaseId}_clinical_review.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const cases = buildCases(reviewerStatus);
const signedOff = reviewerStatus.toLowerCase().includes('signed');
const report = {
  reportType: 'clinical_review',
  generatedAt: new Date().toISOString(),
  releaseId,
  reviewer,
  reviewerStatus,
  publicReleaseDecision: signedOff ? 'eligible_after_other_gates' : 'HOLD',
  cases,
  blockers: signedOff ? [] : ['clinical/domain reviewer sign-off pending'],
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: true, publicReleaseDecision: report.publicReleaseDecision }, null, 2));

function buildCases(status) {
  return [
    {
      caseId: 'clinical_ldopa_protein_window',
      title: 'Levodopa/protein timing',
      expectedReviewFocus: 'High-protein meal near levodopa window should produce cautious, evidence-visible reasoning.',
      requiredEvidence: ['risk reason visible', 'source/evidence reference visible', 'not phrased as mandatory treatment instruction'],
      reviewerStatus: status,
      manualReviewTrigger: 'high risk, missing source, contradictory recommendation, or unresolved placeholder',
    },
    {
      caseId: 'clinical_mineral_dairy_timing',
      title: 'Iron/mineral/dairy timing',
      expectedReviewFocus: 'Mineral or dairy timing interaction should be explained without overclaiming individualized safety.',
      requiredEvidence: ['timing rationale visible', 'fallback copy for missing details', 'professional consultation language retained'],
      reviewerStatus: status,
      manualReviewTrigger: 'missing timing basis, no evidence reference, or absolute medication instruction',
    },
    {
      caseId: 'clinical_missing_timing_fallback',
      title: 'Missing timing fallback',
      expectedReviewFocus: 'Missing next-meal or medication timing should downgrade confidence and avoid confident recommendations.',
      requiredEvidence: ['missing-data warning visible', 'AI/rerank safety gate respected', 'deterministic fallback documented'],
      reviewerStatus: status,
      manualReviewTrigger: 'confident recommendation despite missing timing data',
    },
    {
      caseId: 'clinical_low_risk_no_conflict',
      title: 'Low-risk/no-conflict case',
      expectedReviewFocus: 'Low-risk output should stay readable and not imply zero medical risk.',
      requiredEvidence: ['low-risk label is contextual', 'source basis inspectable when available', 'no unresolved placeholders'],
      reviewerStatus: status,
      manualReviewTrigger: 'zero-risk language or hidden evidence basis',
    },
    {
      caseId: 'clinical_maoi_tyramine_caution',
      title: 'MAOI/tyramine caution',
      expectedReviewFocus: 'Tyramine caution should remain conservative and trigger reviewer attention if source coverage is incomplete.',
      requiredEvidence: ['cautionary language', 'source coverage noted', 'manual review trigger retained for incomplete source data'],
      reviewerStatus: status,
      manualReviewTrigger: 'missing source coverage or advice that changes medication behavior',
    },
  ];
}

function renderMarkdown(report) {
  return `# Clinical Review Report

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Reviewer: ${report.reviewer}
Reviewer status: ${report.reviewerStatus}
Public release decision: ${report.publicReleaseDecision}

| Case | Focus | Reviewer status | Manual review trigger |
| --- | --- | --- | --- |
${report.cases.map((item) => `| ${item.title} | ${item.expectedReviewFocus} | ${item.reviewerStatus} | ${item.manualReviewTrigger} |`).join('\n')}

## Blockers

${report.blockers.length === 0 ? '- none' : report.blockers.map((item) => `- ${item}`).join('\n')}
`;
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next == null || next.startsWith('--')) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
