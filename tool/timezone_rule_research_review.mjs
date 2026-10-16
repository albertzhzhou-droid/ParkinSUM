import assert from 'node:assert/strict';
import{canonical,sha}from'./replay_capsule_fuzz_domain.mjs';
export function reviewTimezoneResearch(domain,reference,actual,manifest) {
  assert.equal(actual.schema,'parkinsum.timezone-rule-research-vectors/1');
  assert.equal(actual.asset_sha256,manifest.asset_sha256);
  assert.equal(actual.civil_observations.length,domain.rows.length*2);
  assert.equal(actual.utc_projections.length,reference.utc_points.length);
  assert.ok(domain.rows.length<=32&&reference.utc_points.length<=64);
  const seen=new Set(),decisions=[];
  for(const row of actual.civil_observations) {
    const key=`${row.release}:${row.id}`;assert.ok(!seen.has(key));seen.add(key);
    const d=domain.rows.find(c=>c.id===row.id);assert.ok(d);const expected=d.expected[row.release];assert.ok(expected);
    assert.equal(row.accepted,expected.accepted,key);
    if(row.accepted) {
      assert.equal(row.utc,expected.utc,key);assert.equal(row.ambiguous,expected.ambiguous,key);
      const body=structuredClone(row.evidence);delete body.sha256_digest;
      assert.equal(sha(canonical(body)),row.evidence.sha256_digest);
      assert.equal(body.tzdb_release,row.release);assert.equal(body.iana_zone_id,d.zone);assert.equal(body.utc_offset_minutes,d.offset_minutes);
      assert.equal(body.resolved_at_utc,expected.utc);
      assert.deepEqual(['year','month','day','hour','minute'].map(k=>body.local_civil_time[k]),d.civil);
      if(row.release==='2026e') {assert.ok(body.provider_identity.includes(manifest.asset_sha256));assert.ok(body.provider_identity.includes(manifest.archive_sha256));}
    }
    decisions.push({key,accepted:row.accepted,utc:row.utc??null,ambiguous:row.ambiguous??null});
  }
  for(const [i,point]of reference.utc_points.entries()) {
    const observation=actual.utc_projections[i];assert.equal(observation.id,point.id);
    assert.equal(observation.epoch_millis,point.epoch_millis);
    assert.deepEqual(observation.civil,point.expected_civil);
    assert.equal(observation.offset_minutes,point.expected_offset_minutes);
  }
  const changed=domain.rows.filter(d=>canonical(d.expected['2025c'])!==canonical(d.expected['2026e'])).map(d=>d.id);
  return{pass:true,civil_comparisons:decisions.length,independent_utc_projections:reference.utc_points.length,changed_interpretations:changed,decisions};
}
