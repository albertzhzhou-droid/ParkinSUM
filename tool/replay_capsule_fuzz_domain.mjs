import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

export const sha = value => createHash('sha256').update(value).digest('hex');
// Separate consistency encoder; acceptance expectations never use either parser.
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export function rehash(value) {
  delete value.capsule_sha256;
  value.capsule_sha256 = sha(canonical(value));
  return value;
}
function random(seed) {
  let state = seed >>> 0;
  return () => { state ^= state << 13; state ^= state >>> 17; state ^= state << 5; return state >>> 0; };
}
export function generateCases(base, plan, seeds = plan.seeds, anchors = true) {
  assert.equal(base.capsule_id, plan.base_capsule_id);
  const families = [...plan.expected_reject_families,...plan.expected_accept_families];
  const cases=[];
  function add(family, seed, index) {
    const value = structuredClone(base);
    const reject=plan.expected_reject_families.includes(family) || family === 'old_schema';
    switch(family) {
      case 'empty_capsule_id': value.capsule_id=''; break;
      case 'whitespace_capsule_id': value.capsule_id=`unsafe ${seed}`; break;
      case 'control_capsule_id': value.capsule_id=`unsafe\n${seed}`; break;
      case 'noncanonical_utc_time': value.generated_at_utc='2026-01-01T08:00:00Z'; break;
      case 'non_utc_time': value.generated_at_utc='2026-01-01T08:00:00.000+00:00'; break;
      case 'invalid_civil_time': value.generated_at_utc='2026-02-30T08:00:00.000Z'; break;
      case 'timezone_authorization': value.timezone_contract.future_civil_time_authorized=true; break;
      case 'timezone_extra_key': value.timezone_contract[`future_${seed}`]=false; break;
      case 'timezone_missing_key': delete value.timezone_contract.iana_zone_id; break;
      case 'ledger_not_object': value.ledger=[]; break;
      case 'context_not_object': value.context=null; break;
      case 'compositions_not_list': value.meal_compositions={}; break;
      case 'future_schema': value.schema_version=2+(seed%2); break;
      case 'old_schema': value.schema_version=0; break;
      case 'valid_same_body': value.capsule_id=`replay_${seed}_${index}`; break;
    }
    rehash(value);
    if(family==='digest_corruption')value.capsule_sha256='0'.repeat(64);
    let raw=canonical(value);
    if(family==='duplicate_member_escaped')raw=raw.replace('"context":{','"context":{"same":true,"sa\\u006de":false,');
    if(family==='depth_33')raw='['.repeat(33)+'null'+']'.repeat(33);
    if(family==='root_order_permutation')raw=JSON.stringify(Object.fromEntries(Object.entries(value).reverse()));
    if(family==='whitespace_transport')raw=' \n'+JSON.stringify(value,null,2)+'\n ';
    cases.push({id:`s${seed}_${index}_${family}`,seed,family,expected_accepted:!reject,raw_json:raw,raw_sha256:sha(raw)});
  }
  for(const seed of seeds) {
    const next=random(seed),order=[...families];
    for(let i=order.length-1;i>0;i--){const j=next()%(i+1);[order[i],order[j]]=[order[j],order[i]];}
    for(let i=0;i<plan.per_seed_budget;i++)add(order[i],seed,i);
  }
  if(anchors)for(const [i,f]of ['valid_same_body','root_order_permutation','whitespace_transport','old_schema','future_schema','duplicate_member_escaped','depth_33','digest_corruption'].entries())add(f,0,i);
  assert.ok(cases.length<=plan.maximum_total_cases);
  assert.ok(cases.every(c=>Buffer.byteLength(c.raw_json)<=plan.maximum_raw_bytes));
  return {schema:'parkinsum.replay-capsule-fuzz-inputs/1',cases};
}

export function structuralTrials(cases, discrepantIds, maximumTrials=72) {
  const trials=[];
  for(const c of cases.filter(c=>discrepantIds.includes(c.id))) {
    let value=JSON.parse(c.raw_json);
    for(const key of ['ledger','context','meal_compositions']) {
      if(value[key] && typeof value[key]==='object')value[key]=Array.isArray(value[key])?[]:{};
      const raw=canonical(rehash(value));
      if(Buffer.byteLength(raw)<Buffer.byteLength(c.raw_json)&&trials.length<maximumTrials)trials.push({...c,id:`${c.id}_shrink_${key}`,original_id:c.id,raw_json:raw,raw_sha256:sha(raw)});
    }
  }
  return {schema:'parkinsum.replay-capsule-fuzz-inputs/1',cases:trials};
}
