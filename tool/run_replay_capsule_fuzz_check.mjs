import assert from 'node:assert/strict';
import{readFileSync,writeFileSync,mkdirSync,existsSync,unlinkSync}from'node:fs';
import{execFileSync}from'node:child_process';
import{captureInputs}from'./verification_runtime.mjs';
import{parseCapsuleJson}from'./mechanistic_replay_capsule_conformance.mjs';
import{generateCases,structuralTrials,sha}from'./replay_capsule_fuzz_domain.mjs';
import{reviewCampaign}from'./replay_capsule_fuzz_review.mjs';

const fixtures='test/fixtures/replay_research/',output='build/replay_capsule_fuzz';
const read=p=>JSON.parse(readFileSync(p));
const before=captureInputs(process.cwd()),plan=read(fixtures+'bounded_campaign_plan.json'),raw=readFileSync(fixtures+'historical_synthetic_base_capsule.json');
assert.equal(sha(raw),plan.base_fixture_transport_sha256);
assert.equal(sha(raw.subarray(0,raw.length-1)),plan.base_raw_sha256);
const domains={seeded:generateCases(JSON.parse(raw),plan),supplemental:read(fixtures+'supplemental_expected.json'),observed_regressions:read(fixtures+'observed_minimized_regressions.json')};
// Load the complete fixed domain and all expected decisions before invoking Dart.
mkdirSync(output,{recursive:true});if(existsSync(output+'/latest.json'))unlinkSync(output+'/latest.json');
const fixtureHashes=Object.fromEntries(['bounded_campaign_plan.json','historical_synthetic_base_capsule.json','supplemental_expected.json','observed_minimized_regressions.json'].map(f=>[f,sha(readFileSync(fixtures+f))]));
const observeNode=input=>input.cases.map(c=>{try{const value=parseCapsuleJson(c.raw_json);return{id:c.id,raw_sha256:c.raw_sha256,accepted:true,capsule_sha256:value.capsule_sha256};}catch(error){return{id:c.id,raw_sha256:c.raw_sha256,accepted:false,reason:error.message};}});
function execute(name,input) {
  const inputPath=`${output}/${name}_inputs.json`,actualPath=`${output}/${name}_dart_actual.json`;
  writeFileSync(inputPath,JSON.stringify(input,null,2)+'\n');if(existsSync(actualPath))unlinkSync(actualPath);
  execFileSync('dart',['run','tool/run_replay_capsule_fuzz_vectors.dart',inputPath,actualPath],{stdio:'inherit',timeout:600000});
  const dart=read(actualPath);assert.equal(dart.input_raw_sha256,sha(readFileSync(inputPath)));
  assert.equal(dart.producer_source_sha256,sha(readFileSync('lib/domain/entities/mechanistic_replay_capsule.dart')));
  const node=observeNode(input),review=reviewCampaign(input,dart,node);
  return{...review,input_raw_sha256:sha(readFileSync(inputPath)),dart_actual_sha256:sha(readFileSync(actualPath)),producer_source_sha256:dart.producer_source_sha256};
}
const campaigns={};
for(const[name,input]of Object.entries(domains)) {
  campaigns[name]=execute(name,input);
  if(!campaigns[name].pass) {
    const disagreements=campaigns[name].rows.filter(r=>r.dart.accepted!==r.node.accepted).map(r=>r.id);
    const trials=structuralTrials(input.cases,disagreements,72);
    if(trials.cases.length)campaigns[name].bounded_structural_trials=execute(`${name}_shrink`,trials);
  }
}
const after=captureInputs(process.cwd());assert.equal(before.sha256,after.sha256,'source drift during campaign');
const pass=Object.values(campaigns).every(c=>c.pass);
const report={schema:'parkinsum.replay-capsule-fuzz-check/1',pass,observed_at_utc:new Date().toISOString(),source_sha256:before.sha256,fixture_sha256:fixtureHashes,seeds:plan.seeds,budgets:{cases_per_campaign:72,structural_trials:72,raw_bytes:plan.maximum_raw_bytes,container_depth:plan.maximum_container_depth},campaigns,source_file_sha256:Object.fromEntries(['lib/domain/entities/mechanistic_replay_capsule.dart','tool/mechanistic_replay_capsule_conformance.mjs','tool/replay_capsule_fuzz_domain.mjs','tool/replay_capsule_fuzz_review.mjs','tool/run_replay_capsule_fuzz_vectors.dart'].map(f=>[f,sha(readFileSync(f))])),boundary:'Finite raw version1 envelope/encoded scalar parity only. Historical synthetic captures are not rebound or typed-restored. Reject unknown old/future versions; no guessed migration, parser universality, signature, authenticity, crash durability or clinical qualification.'};
writeFileSync(output+'/latest.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({pass,campaigns:Object.fromEntries(Object.entries(campaigns).map(([k,v])=>[k,{cases:v.case_count,accepted:v.accepted,rejected:v.rejected,failures:v.failures.length}]))}));
if(!pass)process.exitCode=1;
