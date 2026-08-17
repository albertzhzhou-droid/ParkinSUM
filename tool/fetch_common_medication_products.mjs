#!/usr/bin/env node
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const queries = [
  'carbidopa and levodopa',
  'entacapone',
  'opicapone',
  'rasagiline',
  'selegiline',
  'pramipexole',
  'ropinirole',
  'rotigotine',
  'amantadine',
  'istradefylline',
];
const output = resolve(process.argv[2] ?? 'assets/data/common_medication_products_openfda.json');
const records = new Map();

for (const query of queries) {
  const url = new URL('https://api.fda.gov/drug/ndc.json');
  url.searchParams.set('search', `generic_name:"${query}"`);
  url.searchParams.set('limit', '25');
  const response = await fetch(url, { headers: { accept: 'application/json' } });
  if (!response.ok) throw new Error(`openFDA ${query}: HTTP ${response.status}`);
  const payload = await response.json();
  for (const record of payload.results ?? []) {
    // The NDC directory also contains bulk ingredients and products intended
    // only for further processing. They are not selectable consumer packs.
    if (record.finished !== true || record.product_type !== 'HUMAN PRESCRIPTION DRUG') {
      continue;
    }
    if (!Array.isArray(record.packaging) || record.packaging.length === 0 ||
        !Array.isArray(record.active_ingredients) ||
        !record.active_ingredients.some((item) => item?.name && item?.strength)) {
      continue;
    }
    const key = record.product_ndc;
    if (!key) continue;
    records.set(key, { query, record });
  }
}

const sorted = [...records.values()].sort((a, b) => {
  return String(a.record.generic_name).localeCompare(String(b.record.generic_name)) ||
    String(a.record.product_ndc).localeCompare(String(b.record.product_ndc));
});
const snapshot = {
  schema_version: 1,
  source_system: 'OPENFDA_NDC',
  source_url: 'https://api.fda.gov/drug/ndc.json',
  retrieved_at: new Date().toISOString(),
  limitations: [
    'NDC Directory inclusion does not indicate FDA approval or verified labeling accuracy.',
    'labeler_name may identify a manufacturer, repackager, relabeler, or another label entity.',
    'Package strength is product metadata and must not be treated as the amount a person took.',
  ],
  queries,
  records: sorted,
};
await mkdir(dirname(output), { recursive: true });
await writeFile(output, `${JSON.stringify(snapshot, null, 2)}\n`, 'utf8');
process.stdout.write(`Wrote ${sorted.length} products to ${output}\n`);
