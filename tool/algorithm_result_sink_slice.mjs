import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { canonicalJson } from './independent_algorithm_contract_oracle.mjs';
const hash=v=>createHash('sha256').update(v).digest('hex');
export function sliceResultSinks(graph, plan) {
  if (plan.protocol!=='bounded-result-sink-study-v1' || plan.sinks.length!==3 || new Set(plan.sinks.map(s=>s.id)).size!==3 || !graph.compatibility_accepted || !graph.source_inventory_reconciled || graph.closure_complete!==false) throw new Error('Unqualified input graph or sink plan');
  const budget=plan.budgets;
  if (![budget.maximum_depth,budget.maximum_declarations,budget.maximum_edges].every(Number.isSafeInteger) || budget.maximum_depth<1 || budget.maximum_declarations<1 || budget.maximum_edges<1) throw new Error('Invalid finite budget');
  const bySource=new Map();
  for(const e of graph.declaration_edges){ if(!bySource.has(e.source_declaration_identity))bySource.set(e.source_declaration_identity,[]);bySource.get(e.source_declaration_identity).push(e); }
  const slices=plan.sinks.map(sink=>{
    if(!bySource.has(sink.declaration))throw new Error(`Exact sink not resolved: ${sink.id}`);
    const depths=new Map([[sink.declaration,0]]),queue=[sink.declaration],edges=[],heldTargets=new Set(),depthLimited=new Set();let exceeded=false;
    for(let index=0;index<queue.length;index++){
      const caller=queue[index],depth=depths.get(caller);
      for(const edge of bySource.get(caller)??[]){
        if(edges.length>=budget.maximum_edges){exceeded=true;break;}edges.push(edge);
        if(edge.target_scope!=='local_package'){heldTargets.add(edge.target_identity);continue;}
        if(!bySource.has(edge.target_identity)){heldTargets.add(edge.target_identity);continue;}
        if(depths.has(edge.target_identity))continue;
        if(depth>=budget.maximum_depth){depthLimited.add(edge.target_identity);continue;}
        if(depths.size>=budget.maximum_declarations){exceeded=true;continue;}
        depths.set(edge.target_identity,depth+1);queue.push(edge.target_identity);
      }
      if(edges.length>=budget.maximum_edges)break;
    }
    const sources=[...new Set(edges.map(e=>e.source_package_uri))].sort();
    const unresolved=(graph.source_unresolved??[]).filter(e=>sources.includes(e.source_package_uri));
    const sorted=edges.sort((a,b)=>canonicalJson(a)<canonicalJson(b)?-1:canonicalJson(a)>canonicalJson(b)?1:0);
    return {id:sink.id,exact_sink_declaration:sink.declaration,result:sink.result,resolved_declarations:[...depths].sort(([a],[b])=>a<b?-1:a>b?1:0).map(([declaration,depth])=>({declaration,depth})),direct_supported_edges:sorted,source_package_uris:sources,source_unit_unresolved_context:unresolved,unresolved_context_attribution:'Coarse source-unit context, not exact sink-specific dataflow',external_or_unexpanded_targets:[...heldTargets].sort(),depth_limited_targets:[...depthLimited].sort(),budget_exceeded:exceeded,maximum_observed_depth:Math.max(...depths.values()),namespace_branches:(graph.namespace_edges??[]).filter(e=>sources.includes(e.source_package_uri)),namespace_policy:'Listed as context; imports are not treated as executable call edges',slice_sha256:hash(canonicalJson(sorted)),closure_complete:false,status:'bounded_supported_dependencies_with_explicit_holds'};
  });
  return {protocol:plan.protocol,input_graph_sha256:graph.sha256,accepted_root_count:graph.accepted_root_count,accepted_source_unit_count:graph.accepted_source_unit_count,lib_source_snapshot_sha256:graph.lib_source_snapshot_sha256,plan_sha256:hash(canonicalJson(plan)),budgets:budget,slices,unsupported:plan.unsupported,closure_complete:false,scientific_or_clinical_qualification:false};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const read=p=>JSON.parse(readFileSync(p,'utf8'));const report=sliceResultSinks(read('build/algorithm_direct_edge_probe/latest.json'),read('config/algorithm_result_sink_study.json'));
 mkdirSync('build/algorithm_result_sink_slice',{recursive:true});writeFileSync('build/algorithm_result_sink_slice/latest.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({sinks:report.slices.map(s=>({id:s.id,declarations:s.resolved_declarations.length,edges:s.direct_supported_edges.length,source_units:s.source_package_uris.length,unresolved_groups:s.source_unit_unresolved_context.length,depth_limited:s.depth_limited_targets.length,budget_exceeded:s.budget_exceeded})),closure_complete:false}));
}
