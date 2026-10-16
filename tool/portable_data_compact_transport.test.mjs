import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canonicalDigest,
  canonicalize,
  parseJsonRejectingDuplicates,
  portableCompactLimits,
  resolveCompactPortableFiles,
} from './portable_schema_migration_conformance.mjs';

// Independently authored structural fixtures; these are not fabricated
// timings, the actual Dart benchmark campaign, or clinical validation.
function snapshot(name = 'Source food') {
  return {
    foodId: 'food', foodName: name, foodCategory: 'other', foodTags: [],
    nutrientsPer100g: Object.fromEntries(['protein','carbs','fat','fiber','sodium']
      .map((name) => [name, { value: 0, unit: 'g_per_100g', missing: false,
        rawCompatibilityValue: 0, status: 'catalog_snapshot_value' }])),
    catalogProvenance: {
      status: 'resolved_at_export', sourceSystem: 'TEST', sourceFoodCode: null,
      jurisdiction: null, basisType: null, preparationState: null,
      qualifierKind: null, missingNutrientFields: [], energyKcal: null,
      waterG: null, aminoAcidProfile: null, referenceSnapshotOnly: true,
    },
  };
}

function files({ count = 3, evidence = snapshot(), itemCount = 1 } = {}) {
  const id = canonicalDigest(evidence);
  return {
    'profile.json': {}, 'preferences.json': {}, 'medication_selections.json': [],
    'intakes.json': [], 'reminders.json': [], 'audit_links.json': { links: [] },
    'observations.json': { availability: 'captured_current_local_snapshot', records: [] },
    'meals.json': Array.from({ length: count }, (_, index) => ({
      id: `meal_${index}`, title: 'Source meal',
      time: Object.fromEntries(['eatenAt','recordedAt','occurredAt','occurredRangeStart',
        'occurredRangeEnd','source','precision','nextMealWindowStart','nextMealWindowEnd']
        .map((key) => [key, null])),
      context: { coeventTime: null, coeventSubstanceTags: [], thickenerType: null,
        enteralFeedMode: null, enteralFeedFormula: null, enteralFeedProteinGPerDay: null },
      items: Array.from({ length: itemCount }, () => ({ snapshotId: id,
        quantity: { factorPer100g: 1, grams: 100 } })),
      computedTotalsStatus: 'not_exported_because_unknown_nutrients_must_not_be_summed_as_zero',
    })),
    'food_item_snapshots.json': [{ snapshotId: id, snapshot: evidence }],
  };
}

function wire(value) {
  // The enclosing object puts the embedded files at the actual envelope depth.
  return parseJsonRejectingDuplicates(JSON.stringify({ files: value })).files;
}

function nodes(value) {
  return 1 + (Array.isArray(value) ? value.reduce((n,x) => n + nodes(x),0)
    : value && typeof value === 'object' ? Object.values(value).reduce((n,x) => n + nodes(x),0) : 0);
}

test('independent complete-value node and canonical byte arithmetic agrees', () => {
  const resolved = resolveCompactPortableFiles(wire(files()));
  assert.equal(resolved.logicalNodeCount, nodes(resolved.files));
  assert.equal(resolved.logicalCanonicalBytes, Buffer.byteLength(canonicalize(resolved.files), 'utf8'));
  assert.equal(resolved.files['meals.json'][0].items[0].nutrientsPer100g,
    resolved.files['meals.json'][1].items[0].nutrientsPer100g);
  assert.ok(Object.isFrozen(resolved.files['meals.json'][0].items[0].nutrientsPer100g));
});

test('full evidence identity distinguishes same food ID and unknown from zero', () => {
  const zero = snapshot();
  const missing = snapshot();
  missing.nutrientsPer100g.protein = { value: null, unit: 'g_per_100g',
    missing: true, rawCompatibilityValue: 999, status: 'source_missing_not_zero' };
  assert.equal(zero.foodId, missing.foodId);
  assert.notEqual(canonicalDigest(zero), canonicalDigest(missing));
  const input = files({ evidence: zero, count: 2 });
  const missingId = canonicalDigest(missing);
  input['food_item_snapshots.json'].push({ snapshotId: missingId, snapshot: missing });
  input['food_item_snapshots.json'].sort((a,b) => a.snapshotId.localeCompare(b.snapshotId));
  input['meals.json'][1].items[0].snapshotId = missingId;
  const resolved = resolveCompactPortableFiles(wire(input));
  assert.equal(resolved.files['meals.json'][0].items[0].nutrientsPer100g.protein.value, 0);
  assert.equal(resolved.files['meals.json'][1].items[0].nutrientsPer100g.protein.value, null);
  assert.equal(resolved.files['meals.json'][1].items[0].nutrientsPer100g.protein.rawCompatibilityValue, 999);
});

test('reference resolution retains Dart floating-point tokens in snapshots and quantities', () => {
  const input = files();
  const original = input['food_item_snapshots.json'][0].snapshot;
  let source = JSON.stringify(original).replace('"rawCompatibilityValue":0', '"rawCompatibilityValue":-0.0');
  const typedSnapshot = parseJsonRejectingDuplicates(source);
  const id = canonicalDigest(typedSnapshot);
  input['food_item_snapshots.json'] = [{ snapshotId: id, snapshot: typedSnapshot }];
  for (const meal of input['meals.json']) meal.items[0].snapshotId = id;
  // Canonicalize uses the retained lexical metadata rather than JSON.stringify.
  source = canonicalize({ files: input }).replace('"factorPer100g":1', '"factorPer100g":1.0');
  const parsed = parseJsonRejectingDuplicates(source).files;
  const resolved = resolveCompactPortableFiles(parsed);
  assert.match(canonicalize(resolved.files), /"rawCompatibilityValue":-0\.0/);
  assert.match(canonicalize(resolved.files), /"factorPer100g":1\.0/);
  assert.equal(resolved.logicalCanonicalBytes, Buffer.byteLength(canonicalize(resolved.files), 'utf8'));
});

for (const [name, mutate, reason] of [
  ['dangling', (v) => v['meals.json'][0].items[0].snapshotId = 'f'.repeat(64), /snapshot_reference/],
  ['duplicate', (v) => v['food_item_snapshots.json'].push(v['food_item_snapshots.json'][0]), /snapshot_id_or_order/],
  ['checksum', (v) => v['food_item_snapshots.json'][0].snapshot.foodName = 'Tampered', /snapshot_checksum/],
  ['unknown reference field', (v) => v['meals.json'][0].items[0].hidden = true, /key_mismatch/],
  ['unknown snapshot field', (v) => v['food_item_snapshots.json'][0].snapshot.hidden = true, /key_mismatch/],
  ['unknown entry field', (v) => v['food_item_snapshots.json'][0].hidden = true, /key_mismatch/],
  ['unknown quantity field', (v) => v['meals.json'][0].items[0].quantity.hidden = true, /key_mismatch/],
]) {
  test(`compact ${name} fails before use`, () => {
    const input = files(); mutate(input);
    assert.throws(() => resolveCompactPortableFiles(wire(input)), reason);
  });
}

test('unused valid snapshot and reversed snapshot order are both refused', () => {
  const input = files();
  const extra = snapshot('Unused');
  input['food_item_snapshots.json'].push({ snapshotId: canonicalDigest(extra), snapshot: extra });
  input['food_item_snapshots.json'].sort((a,b) => a.snapshotId.localeCompare(b.snapshotId));
  assert.throws(() => resolveCompactPortableFiles(wire(input)), /unused_snapshot/);
  input['food_item_snapshots.json'].reverse();
  assert.throws(() => resolveCompactPortableFiles(wire(input)), /snapshot_id_or_order/);
});

test('permitted shallow wire cannot cause an unbounded node expansion', () => {
  const evidence = snapshot(); evidence.foodTags = Array(3000).fill('x');
  const input = files({ evidence, count: 1, itemCount: 1000 });
  assert.ok(nodes(input) < 500000);
  const parsed = wire(input);
  assert.throws(() => resolveCompactPortableFiles(parsed), /logical_node_budget/);
});

test('permitted string cannot multiply past logical canonical byte budget', () => {
  const input = files({ evidence: snapshot('x'.repeat(65536)), count: 1, itemCount: 600 });
  const parsed = wire(input);
  assert.throws(() => resolveCompactPortableFiles(parsed), /logical_byte_budget/);
});

test('wire depth 24 cannot amplify to logical envelope depth 25', () => {
  const evidence = snapshot(); let value = 0;
  for (let i = 0; i < 17; i++) value = { a: value };
  evidence.catalogProvenance.aminoAcidProfile = value;
  const parsed = wire(files({ evidence }));
  assert.throws(() => resolveCompactPortableFiles(parsed), /logical_depth_budget/);
});

test('unchanged lexical node budget and escaped duplicate protection remain active', () => {
  assert.throws(() => parseJsonRejectingDuplicates(`[${Array(500000).fill('0').join(',')}]`), /node_budget/);
  assert.throws(() => parseJsonRejectingDuplicates('{"a":1,"\\u0061":2}'), /duplicate_object_member/);
  assert.equal(portableCompactLimits.logicalFileNodes, 1200000);
});
