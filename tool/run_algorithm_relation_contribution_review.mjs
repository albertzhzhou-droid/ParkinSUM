import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { evaluateRelation, canonicalJson } from './independent_algorithm_contract_oracle.mjs';
const hash = value => createHash('sha256').update(value).digest('hex');
const read = p => JSON.parse(readFileSync(p, 'utf8'));
export function reviewContribution({ current, fixture, registry, sourceHashes, producerHash }) {
  const failures = [];
  const relations = new Map(registry.relations.map(r => [r.id,r]));
  if (fixture.protocol !== 'bounded-compiled-relation-contribution-v1' || fixture.mutations.length !== 6 || !fixture.all_original_sources_restored_exact) failures.push('historical_witness_contract');
  if (producerHash !== fixture.producer_sha256 || current.producer_sha256 !== producerHash) failures.push('producer_drift');
  for (const [path,expected] of Object.entries(fixture.original_source_sha256)) if (sourceHashes[path] !== expected || current.actual_source_sha256[path] !== expected) failures.push(`source_drift:${path}`);
  const cases = current.cases ?? [];
  const ids = new Set();
  const evaluations = cases.map(row => {
    const id = `${row.relation_id}.${row.partition}.${row.seed}`;
    if (ids.has(id)) failures.push('duplicate_case'); ids.add(id);
    if (!fixture.plan.seeds.includes(row.seed) || !fixture.plan.partitions.includes(row.partition) || !(row.source_api_invocation_count>0 && row.follow_up_api_invocation_count>0)) failures.push('case_domain_or_actual_call');
    const f = evaluateRelation(relations.get(row.relation_id),row.relation_observation);
    return {id,relation_id:row.relation_id,failures:f};
  });
  if (cases.length !== 96 || hash(canonicalJson(cases)) !== fixture.baseline_case_sha256) failures.push('generator_or_observation_drift');
  if (evaluations.some(e=>e.failures.length)) failures.push('current_relation_false_positive_or_regression');
  const matrix = [];
  for (const row of fixture.mutations) {
    const m=row.mutation, relation=relations.get(row.baseline_witness.relation_id);
    const old=evaluateRelation(relation,row.baseline_witness.relation_observation);
    const fresh=evaluateRelation(relation,row.mutant_witness.relation_observation);
    if (!row.actual_compiled || row.ir_only_mutation || old.length) failures.push(`actual_mutation_contract:${m.id}`);
    if (m.class==='expected_kill' && (fresh.length===0 || row.actual_changed_paired_cases!==12 || m.target_relation!==relation.id)) failures.push(`specific_fault_not_detected:${m.id}`);
    if (m.class!=='expected_kill' && (fresh.length || row.actual_changed_paired_cases!==0)) failures.push(`control_or_survivor_drift:${m.id}`);
    const detected=m.class==='expected_kill';
    matrix.push({mutation_id:m.id,class:m.class,killed_by_relations:detected?[m.target_relation]:[],actual_changed_paired_cases:row.actual_changed_paired_cases,scope:'96 actual paired executions; mutant attribution independently reviewed from complete local observations'});
  }
  const scope=fixture.mutations.find(r=>r.mutation.id==='fact_scope_collapsed');
  const baseTrials=fixture.baseline_minimal_scope_trials;
  const lookup=(rows,id)=>rows.find(r=>r.id===id);
  if (lookup(baseTrials,'one_fact_different_scope')?.classification!=='coexistVariant' || lookup(scope.auxiliary_trials,'one_fact_different_scope')?.classification!=='contradiction' || lookup(baseTrials,'zero_fact_different_scope')?.classification!==lookup(scope.auxiliary_trials,'zero_fact_different_scope')?.classification) failures.push('bounded_minimal_counterexample_drift');
  const survivor=fixture.mutations.find(r=>r.mutation.id==='contradiction_reason_survivor');
  if (lookup(survivor.auxiliary_trials,'one_fact_same_scope')?.reason===lookup(baseTrials,'one_fact_same_scope')?.reason) failures.push('semantic_survivor_not_observed');
  const unreached=fixture.mutations.find(r=>r.mutation.id==='cluster_empty_status_unobserved');
  if (unreached.empty_cluster_auxiliary.status===fixture.baseline_empty_cluster_auxiliary.status) failures.push('unobserved_branch_not_separately_witnessed');
  const defectiveRelationFalsePositives=cases.filter(r=>r.relation_id==='fact_conflict.order_and_scope' && r.relation_observation.different_scope!=='contradiction').length;
  return {protocol:fixture.protocol,passed:failures.length===0,failures:[...new Set(failures)],actual_paired_cases:cases.length,actual_api_calls:cases.reduce((n,r)=>n+r.source_api_invocation_count+r.follow_up_api_invocation_count,0),finite_valid_reference_false_positives:{numerator:evaluations.filter(e=>e.failures.length).length,denominator:cases.length,clinical_rate:false},defective_overbroad_relation_false_positives:{numerator:defectiveRelationFalsePositives,denominator:12},marginal_detection_matrix:matrix,three_specific_compiled_faults_detected:matrix.filter(r=>r.killed_by_relations.length).length,semantic_survivors:1,generator_unobserved_mutations:1,equivalent_source_controls:1,minimum_scope_witness:'Within five actual trials: one observation and one fact; deleting the sole fact removes the observed scope defect. No globally minimal claim.',full_semantic_branch_coverage:false,compiled_fault_records_are_historical:true};
}
if (process.argv[1]===fileURLToPath(import.meta.url)) {
 const fixture=read('test/fixtures/relation_compiled_contribution_witnesses_v2.json');
 const report=reviewContribution({current:read('build/algorithm_relation_contribution/current.json'),fixture,registry:read('config/algorithm_contract_relation_registry.json'),sourceHashes:Object.fromEntries(Object.keys(fixture.original_source_sha256).map(p=>[p,hash(readFileSync(p))])),producerHash:hash(readFileSync('tool/run_algorithm_relation_contribution_study.dart'))});
 mkdirSync('build/algorithm_relation_contribution',{recursive:true});writeFileSync('build/algorithm_relation_contribution/review.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(!report.passed)process.exitCode=1;
}
