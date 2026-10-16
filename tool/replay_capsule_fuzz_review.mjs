import assert from 'node:assert/strict';
import {sha,canonical} from './replay_capsule_fuzz_domain.mjs';

export function reviewCampaign(input, dart, node) {
  assert.equal(dart.schema,'parkinsum.replay-capsule-fuzz-dart-vectors/1');
  assert.equal(input.cases.length,dart.cases.length);
  assert.equal(input.cases.length,node.length);
  assert.ok(input.cases.length<=72);
  const ids=new Set(),failures=[],rows=[];
  for(const [i,c]of input.cases.entries()) {
    assert.ok(!ids.has(c.id),'duplicate case ID');ids.add(c.id);
    assert.equal(sha(c.raw_json),c.raw_sha256);
    const d=dart.cases[i],n=node[i];
    assert.equal(d.id,c.id);assert.equal(n.id,c.id);
    assert.equal(d.raw_sha256,c.raw_sha256);assert.equal(n.raw_sha256,c.raw_sha256);
    assert.equal(typeof d.accepted,'boolean');assert.equal(typeof n.accepted,'boolean');
    if(d.accepted!==c.expected_accepted)failures.push(`${c.id}:dart_expected_mismatch`);
    if(n.accepted!==c.expected_accepted)failures.push(`${c.id}:node_expected_mismatch`);
    if(d.accepted!==n.accepted)failures.push(`${c.id}:runtime_disagreement`);
    if(d.accepted&&n.accepted) {
      const value=JSON.parse(c.raw_json);
      assert.equal(d.canonical_sha256,sha(canonical(value)),'accepted canonical text mismatch');
      assert.equal(n.capsule_sha256,d.capsule_sha256);
    }
    rows.push({id:c.id,family:c.family,seed:c.seed??null,raw_sha256:c.raw_sha256,expected_accepted:c.expected_accepted,dart:d,node:n});
  }
  return {pass:failures.length===0,failures,case_count:rows.length,accepted:rows.filter(r=>r.dart.accepted).length,rejected:rows.filter(r=>!r.dart.accepted).length,families:[...new Set(rows.map(r=>r.family))].sort(),rows};
}
