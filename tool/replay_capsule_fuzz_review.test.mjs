import assert from 'node:assert/strict';
import test from 'node:test';
import{readFileSync}from'node:fs';
import{generateCases,structuralTrials,sha}from'./replay_capsule_fuzz_domain.mjs';
import{reviewCampaign}from'./replay_capsule_fuzz_review.mjs';
import{parseCapsuleJson}from'./mechanistic_replay_capsule_conformance.mjs';
const fixture='test/fixtures/replay_research/',read=f=>JSON.parse(readFileSync(fixture+f));
test('fixed family campaign is reproducible, bounded and includes old/future schema abstention',()=>{
  const p=read('bounded_campaign_plan.json'),base=read('historical_synthetic_base_capsule.json');
  const a=generateCases(base,p),b=generateCases(base,p);assert.deepEqual(a,b);assert.equal(a.cases.length,72);
  for(const family of [...p.expected_accept_families,...p.expected_reject_families,'old_schema'])assert.ok(a.cases.some(c=>c.family===family));
  for(const c of a.cases){assert.equal(sha(c.raw_json),c.raw_sha256);if(c.expected_accepted)assert.doesNotThrow(()=>parseCapsuleJson(c.raw_json));else assert.throws(()=>parseCapsuleJson(c.raw_json));}
});
test('observed structural minima remain rejected after independent checker repair',()=>{
  const corpus=read('observed_minimized_regressions.json');assert.equal(corpus.cases.length,20);
  for(const c of corpus.cases){assert.equal(sha(c.raw_json),c.raw_sha256);assert.throws(()=>parseCapsuleJson(c.raw_json));}
  assert.ok(structuralTrials(corpus.cases,corpus.cases.map(c=>c.id),2).cases.length<=2);
});
test('review reports manufactured runtime disagreement and expected mismatch',()=>{
  const input={cases:[{id:'negative',family:'fixture',expected_accepted:false,raw_json:'{}',raw_sha256:sha('{}')}]};
  const dart={schema:'parkinsum.replay-capsule-fuzz-dart-vectors/1',cases:[{id:'negative',raw_sha256:sha('{}'),accepted:false}]};
  const node=[{id:'negative',raw_sha256:sha('{}'),accepted:true}];
  const report=reviewCampaign(input,dart,node);assert.equal(report.pass,false);assert.deepEqual(report.failures,['negative:node_expected_mismatch','negative:runtime_disagreement']);
});
test('review rejects stale raw identity and duplicate case identity',()=>{
  const c={id:'same',family:'fixture',expected_accepted:false,raw_json:'{}',raw_sha256:sha('{}')},d={...c,accepted:false};
  assert.throws(()=>reviewCampaign({cases:[c]},{schema:'parkinsum.replay-capsule-fuzz-dart-vectors/1',cases:[{...d,raw_sha256:'0'.repeat(64)}]},[d]),/AssertionError/);
  assert.throws(()=>reviewCampaign({cases:[c,c]},{schema:'parkinsum.replay-capsule-fuzz-dart-vectors/1',cases:[d,d]},[d,d]),/duplicate case/);
});
test('fixed calendar and scalar type supplement preserves declared decisions',()=>{
  for(const c of read('supplemental_expected.json').cases){if(c.expected_accepted)assert.doesNotThrow(()=>parseCapsuleJson(c.raw_json));else assert.throws(()=>parseCapsuleJson(c.raw_json));}
});
