import assert from'node:assert/strict';
import test from'node:test';
import{reviewTimezoneResearch}from'./timezone_rule_research_review.mjs';
import{canonical,sha}from'./replay_capsule_fuzz_domain.mjs';
function manufactured() {
  const expected={accepted:true,utc:'2026-01-15T17:30:00.000Z',ambiguous:false},row={id:'manual',zone:'America/Toronto',civil:[2026,1,15,12,30],offset_minutes:-300,expected:{'2025c':expected,'2026e':expected}};
  const asset='a'.repeat(64),archive='b'.repeat(64);
  const observations=['2025c','2026e'].map(release=>{const body={tzdb_release:release,iana_zone_id:row.zone,utc_offset_minutes:-300,resolved_at_utc:expected.utc,local_civil_time:{year:2026,month:1,day:15,hour:12,minute:30},provider_identity:`${asset}:${archive}`};return{id:row.id,release,...expected,evidence:{...body,sha256_digest:sha(canonical(body))}};});
  return{domain:{rows:[row]},reference:{utc_points:[{id:'utc',epoch_millis:1,expected_civil:[2026,1,15,12,30,0],expected_offset_minutes:-300}]},actual:{schema:'parkinsum.timezone-rule-research-vectors/1',asset_sha256:asset,civil_observations:observations,utc_projections:[{id:'utc',epoch_millis:1,civil:[2026,1,15,12,30,0],offset_minutes:-300}]},manifest:{asset_sha256:asset,archive_sha256:archive}};
}
test('independent reviewer accepts complete manufactured reference binding',()=>{const x=manufactured();assert.equal(reviewTimezoneResearch(x.domain,x.reference,x.actual,x.manifest).pass,true);});
test('independent reviewer rejects false accept, wrong offset and moved UTC instant',()=>{
  for(const change of [x=>x.actual.civil_observations[0].accepted=false,x=>x.actual.utc_projections[0].offset_minutes=-360,x=>x.actual.utc_projections[0].epoch_millis=2]){const x=manufactured();change(x);assert.throws(()=>reviewTimezoneResearch(x.domain,x.reference,x.actual,x.manifest));}
});
test('independent reviewer rejects rebased evidence, truncated output and duplicate identities',()=>{
  for(const change of [x=>x.actual.civil_observations[0].evidence.tzdb_release='2026e',x=>x.actual.civil_observations.pop(),x=>x.actual.civil_observations[1]=x.actual.civil_observations[0]]){const x=manufactured();change(x);assert.throws(()=>reviewTimezoneResearch(x.domain,x.reference,x.actual,x.manifest));}
});
test('independent reviewer rejects unbound current provider and changed asset',()=>{
  const x=manufactured();const evidence=x.actual.civil_observations[1].evidence;evidence.provider_identity='unbound';const body=structuredClone(evidence);delete body.sha256_digest;evidence.sha256_digest=sha(canonical(body));assert.throws(()=>reviewTimezoneResearch(x.domain,x.reference,x.actual,x.manifest));
  const y=manufactured();y.actual.asset_sha256='c'.repeat(64);assert.throws(()=>reviewTimezoneResearch(y.domain,y.reference,y.actual,y.manifest));
});
