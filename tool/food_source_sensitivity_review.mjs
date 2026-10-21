import assert from 'node:assert/strict';
export const SCORE_TOLERANCE=1e-9;
const near=(actual,expected,label)=>{assert.equal(typeof actual,'number',label);assert(Number.isFinite(actual)&&Math.abs(actual-Number(expected))<=SCORE_TOLERANCE,`${label}: ${actual} != ${expected}`);};
export function reviewJoint(expectations,actual) {
  assert.equal(actual.legal_joint_combinations,expectations.legal_joint_combinations);
  assert.equal(actual.scenarios.length,expectations.legal_joint_combinations*expectations.windows.length);
  assert.equal(actual.source_macro_basis,'per_100g_edible_part');assert.equal(actual.component_macro_basis,'per_explicit_source_portion');
  const options=new Map(expectations.groups.flatMap(g=>g.options.map(o=>[o.option_id,{...o,candidate_id:g.candidate_id}])));
  const ids=new Set();let checked=0;
  for(const row of actual.scenarios){
    assert(!ids.has(row.scenario_id));ids.add(row.scenario_id);assert.equal(row.choices.length,expectations.groups.length);
    const groupIds=new Set();
    for(const c of row.choices){const e=options.get(c.option_id);assert(e);assert.equal(c.candidate_id,e.candidate_id);assert(!groupIds.has(c.candidate_id));groupIds.add(c.candidate_id);assert.equal(c.fdc_id,e.fdc_id);assert.equal(c.portion_id,e.portion_id);assert.equal(c.portion_record_locator,`${e.fdc_id}:foodPortions:${e.original_food_portion_index}`);near(c.portion_grams,e.portion_grams,'portion');for(const [k,v]of Object.entries(e.expected_per_portion)){near(c.per_portion[k],v,`${c.option_id}:${k}`);checked++;}}
    assert.equal(row.results.length,row.choices.length);assert.deepEqual([...row.results.map(r=>r.candidate_id)].sort(),[...groupIds].sort());
    for(const result of row.results){if(result.availability==='available'){assert(Number.isFinite(result.score)&&result.score>=0&&result.score<=1);}else assert.equal(result.score,null);}
  }
  assert.equal(actual.probabilities,null);assert.equal(actual.clinical_confidence,null);assert.equal(actual.production_default_changed,false);
  return {portion_macro_comparisons:checked,...rankSummary(actual.scenarios.map(s=>({id:s.scenario_id,stratum:s.window_id,inputs:Object.fromEntries(s.choices.map(c=>[c.candidate_id,c.option_id])),results:s.results.map(r=>({id:r.candidate_id,score:r.score,availability:r.availability}))})),[1,2,3])};
}
// Independently specified analytic branches. Does not import Dart, production
// output or production parameters to manufacture the expected score. The
// synthetic domain foods carry no source portion and no product category, so
// thresholds compare their per-100 g values and every food is tagged
// `serving_unknown_per_100g` (legacy parameter set v3).
export function expectedHeuristic(food,p) {
 const protein=Number(food.protein_g),fiber=Number(food.fiber_g);
 const features={safety_score:protein>=25?.4:protein>=Number(p.caution_protein_g)?.65:.95,nutrient_match:fiber>=2?.85:.7,medication_schedule_fit:protein>=20?.5:.82,drug_timing_sensitivity:protein>=20?1:protein>=15?.7:.35,fiber_support_score:fiber>=4?1:fiber>=2?.8:.45};
 const raw=100*(Number(p.safety_weight)*features.safety_score+.2*features.nutrient_match+.15*features.medication_schedule_fit+.1*.72+.1*.68+.05*.95+.03+.02+Number(p.fiber_weight)*features.fiber_support_score-.04*features.drug_timing_sensitivity);
 return {id:food.id,score:Math.max(0,Math.min(100,raw)),raw,features,decision:protein>=Number(p.warning_protein_g)?'WARN':'ALLOW',risk_tags:['levodopa_sensitive',...(protein>=Number(p.warning_protein_g)?['high_protein_candidate']:[]),'serving_unknown_per_100g','timing_window_unclear']};
}
export function reviewHeuristic(domain,actual) {
 assert.deepEqual(actual.default_parameters_before,actual.default_parameters_after);assert.equal(actual.production_defaults_changed,false);assert.equal(actual.cases.length,domain.cases.length);
 let comparisons=0;const observed=[];const decisions=new Map();
 for(const c of domain.cases){const row=actual.cases.find(r=>r.id===c.id);assert(row);assert.deepEqual(row.parameters,c.parameters);assert.equal(row.results.length,domain.foods.length);assert.equal(new Set(row.results.map(r=>r.id)).size,domain.foods.length);
  const byId=new Map(row.results.map(r=>[r.id,r]));const expected=domain.foods.map(f=>expectedHeuristic(f,c.parameters));
  for(const e of expected){const r=byId.get(e.id);assert(r);near(r.score,e.score,`${c.id}:${e.id}`);near(r.score_breakdown.unbounded_score_points,e.raw,'unbounded');assert.equal(r.decision,e.decision);assert.deepEqual(r.feature_snapshot.risk_tags,e.risk_tags);assert.equal(r.feature_snapshot.has_precise_timing_window,false);assert.equal(r.feature_snapshot.timing_window_clarity,0);for(const [key,value] of Object.entries(e.features)){near(r.feature_snapshot[key],value,key);comparisons++;}decisions.set(e.id,new Set([...(decisions.get(e.id)??[]),r.decision]));}
  // Require every mathematically separated pair to remain in score order;
  // declared rounding-level ties are reported separately, not overclaimed.
  const positions=new Map(row.results.map((r,i)=>[r.id,i]));for(const a of expected)for(const b of expected)if(a.score-b.score>SCORE_TOLERANCE)assert(positions.get(a.id)<positions.get(b.id),'independent order');
  assert(positions.get('tie_a')<positions.get('tie_b'),'exact identical-feature ties break by ID');
  observed.push({id:c.id,stratum:'fixed_grid',inputs:c.parameters,results:row.results.map(r=>({id:r.id,score:r.score,availability:'heuristic_legacy',decision:r.decision}))});
 }
 return {feature_comparisons:comparisons,decision_changes:[...decisions].filter(([,d])=>d.size>1).map(([id])=>id).sort(),...rankSummary(observed,domain.top_k,'safety.4_fiber.02_caution15_warning20')};
}
export function rankSummary(rows,topK,baselineId) {
 const result=[];for(const stratum of [...new Set(rows.map(r=>r.stratum))].sort()){
  const samples=rows.filter(r=>r.stratum===stratum);const baseline=samples.find(r=>r.id===baselineId)??samples[0];const available=r=>r.results.filter(x=>typeof x.score==='number'&&Number.isFinite(x.score));
  const baselineOrder=available(baseline).map(r=>r.id),orders=new Map(),ties=[],topChanges=Object.fromEntries(topK.map(k=>[k,[]])),pairs=new Map();let abstentions=0;
  for(const row of samples){const ranked=available(row),order=ranked.map(r=>r.id);abstentions+=row.results.length-ranked.length;const signature=order.join('|');orders.set(signature,(orders.get(signature)??0)+1);
   for(const k of topK){const a=baselineOrder.slice(0,k).sort().join('|'),b=order.slice(0,k).sort().join('|');if(a!==b)topChanges[k].push(row.id);}
   const sorted=[...ranked].sort((a,b)=>a.id.localeCompare(b.id,'en'));for(let i=0;i<sorted.length;i++)for(let j=i+1;j<sorted.length;j++){const a=sorted[i],b=sorted[j],key=`${a.id}|${b.id}`,diff=a.score-b.score,sign=Math.abs(diff)<=SCORE_TOLERANCE?0:Math.sign(diff);if(sign===0)ties.push({scenario_id:row.id,candidates:[a.id,b.id],scores:[a.score,b.score]});const entries=pairs.get(key)??[];entries.push({row,sign});pairs.set(key,entries);}
  }
  const reversed=[],stable=[],unresolved=[];
  for(const [pair,entries] of pairs){const plus=entries.filter(e=>e.sign===1),minus=entries.filter(e=>e.sign===-1);if(plus.length&&minus.length){let best;for(const a of plus)for(const b of minus){const dimensions=[...new Set([...Object.keys(a.row.inputs),...Object.keys(b.row.inputs)])].filter(k=>a.row.inputs[k]!==b.row.inputs[k]);if(!best||dimensions.length<best.changed_dimensions.length)best={first_scenario:a.row.id,second_scenario:b.row.id,changed_dimensions:dimensions,first_inputs:a.row.inputs,second_inputs:b.row.inputs};}reversed.push({pair,minimum_changed_dimension_counterexample:best});}else if(entries.every(e=>e.sign!==0))stable.push(pair);else unresolved.push(pair);}
  result.push({stratum,baseline_scenario:baseline.id,scenario_count:samples.length,abstained_results:abstentions,distinct_orders:[...orders].map(([order,count])=>({order:order?order.split('|'):[],count})),numeric_ties:ties,top_k_membership_changes:topChanges,reversed_pairs:reversed,stable_strict_pairs_in_evaluated_domain:stable,tied_or_unresolved_pairs:unresolved});
 }
 return {strata:result,tie_absolute_tolerance:SCORE_TOLERANCE,full_rank_stability_assessed:false,clinical_confidence:null,probabilities:null};
}
