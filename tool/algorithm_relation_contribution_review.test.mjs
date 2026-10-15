import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { reviewContribution } from './run_algorithm_relation_contribution_review.mjs';
const read=p=>JSON.parse(readFileSync(p,'utf8'));
const fixture=read('test/fixtures/relation_compiled_contribution_witnesses_v2.json');
const baseline=read('build/algorithm_relation_contribution/current.json');
const args=()=>({current:structuredClone(baseline),fixture:structuredClone(fixture),registry:read('config/algorithm_contract_relation_registry.json'),sourceHashes:{...fixture.original_source_sha256},producerHash:fixture.producer_sha256});
test('actual compiled faults, finite false positives, survivor and unreachable branch stay distinct',()=>{const r=reviewContribution(args());assert.equal(r.passed,true);assert.equal(r.three_specific_compiled_faults_detected,3);assert.equal(r.semantic_survivors,1);assert.equal(r.defective_overbroad_relation_false_positives.numerator,12);assert.equal(r.full_semantic_branch_coverage,false);});
test('retained v1 campaign cannot qualify the changed current conflict source',()=>{const a=args();a.fixture=read('test/fixtures/relation_compiled_contribution_witnesses_v1.json');const r=reviewContribution(a);assert.equal(r.passed,false);assert.ok(r.failures.includes('source_drift:lib/domain/usecases/fact_conflict_engine.dart'));});
for(const [name,change] of [
 ['compiled evidence replaced by IR',a=>a.fixture.mutations[0].ir_only_mutation=true],
 ['fault artificially declared killed',a=>a.fixture.mutations[0].mutant_witness=a.fixture.mutations[0].baseline_witness],
 ['source changed',a=>a.sourceHashes[Object.keys(a.sourceHashes)[0]]='0'.repeat(64)],
 ['generator case dropped',a=>a.current.cases.pop()],
 ['survivor silently called equivalent',a=>a.fixture.mutations.find(r=>r.mutation.id==='contradiction_reason_survivor').auxiliary_trials=a.fixture.baseline_minimal_scope_trials],
 ['unobserved branch without actual auxiliary witness',a=>a.fixture.mutations.find(r=>r.mutation.id==='cluster_empty_status_unobserved').empty_cluster_auxiliary=a.fixture.baseline_empty_cluster_auxiliary],
 ]) test(name,()=>{const a=args();change(a);assert.equal(reviewContribution(a).passed,false);});
