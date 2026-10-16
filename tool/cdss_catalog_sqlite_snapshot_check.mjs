// Independent actual SQLite WAL experiment; no production expectation generator.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
const SCHEMA = 'parkinsum.cdss-catalog-sqlite-snapshot-check/1';
const experiment = String.raw`
import json,sqlite3,tempfile,pathlib
with tempfile.TemporaryDirectory(prefix='parkinsum_catalog_sqlite_') as root:
 p=str(pathlib.Path(root)/'synthetic.db')
 reader=sqlite3.connect(p,isolation_level=None); writer=sqlite3.connect(p,isolation_level=None)
 reader.execute('pragma journal_mode=WAL')
 for table in ['food','observation','source']:
  reader.execute('create table '+table+'(revision integer not null)')
  reader.execute('insert into '+table+' values(0)')
 def revision(db,table):return db.execute('select revision from '+table).fetchone()[0]
 def publish(value):
  writer.execute('begin immediate')
  for table in ['food','observation','source']:writer.execute('update '+table+' set revision=?',(value,))
  writer.execute('commit')
 samples=[]
 for old in range(12):
  reader.execute('begin');first=revision(reader,'food');publish(old+1)
  whole=[first,revision(reader,'observation'),revision(reader,'source')]
  assert whole==[old]*3,whole
  reader.execute('commit')
  new=[revision(reader,t) for t in ['food','observation','source']]
  assert new==[old+1]*3,new
  samples.append({'old':whole,'new':new})
 # Control: separate autocommit reads really can manufacture a mixed view.
 first=revision(reader,'food');publish(13)
 mixed=[first,revision(reader,'observation'),revision(reader,'source')]
 assert mixed==[12,13,13]
 writer.execute('begin immediate');writer.execute('update food set revision=999');writer.execute('rollback')
 assert [revision(reader,t) for t in ['food','observation','source']]==[13]*3
 print(json.dumps({'pass':True,'transaction_interleavings':samples,'sequential_counterexample':mixed,'rollback_preserves_whole_state':True,'sqlite_version':sqlite3.sqlite_version}))
 reader.close();writer.close()
`;
const sha = value => createHash('sha256').update(value).digest('hex');
const observed = JSON.parse(execFileSync('python3', ['-c', experiment], {encoding:'utf8'}));
const report = {schema:SCHEMA, ...observed,
  experiment_sha256:sha(experiment),
  production_source_sha256:Object.fromEntries([
    'lib/core/db/cdss_catalog_snapshot_reader.dart',
    'lib/core/db/cdss_database_native.dart',
    'lib/domain/usecases/cdss_catalog_projection_service.dart',
  ].map(p=>[p,sha(readFileSync(p))])),
  boundary:'Actual synthetic SQLite WAL semantics via independent Python driver. Does not execute a Flutter native plugin, a device, Web cross-tab transactions, or clinical validation. Production projection semantics are separately unit-tested.'};
mkdirSync('build/cdss_catalog_snapshot',{recursive:true});
writeFileSync('build/cdss_catalog_snapshot/sqlite.json',JSON.stringify(report,null,2)+'\n');
console.log(`PASS 12 whole-old/whole-new transaction interleavings; sequential mixed-view counterexample detected; SQLite ${observed.sqlite_version}`);
