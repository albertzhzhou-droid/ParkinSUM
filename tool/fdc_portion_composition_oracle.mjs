import { createHash } from 'node:crypto';

// Deliberately separate JavaScript implementation for shared conversion
// vectors. It verifies bounded mechanics, not source authenticity or utility.
export function canonicalizeFdcPortionProjection(value) {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('non-finite report number');
    const binary64 = Buffer.allocUnsafe(8);
    binary64.writeDoubleBE(value, 0);
    return JSON.stringify(`f64:${binary64.toString('hex')}`);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalizeFdcPortionProjection).join(',')}]`;
  }
  if (typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalizeFdcPortionProjection(value[key])}`).join(',')}}`;
  }
  throw new TypeError('unsupported report value');
}

export function fdcPortionProjectionSha256(payload) {
  return createHash('sha256')
    .update(canonicalizeFdcPortionProjection(payload), 'utf8')
    .digest('hex');
}

export function calculateFdcPortionComposition(vector) {
  const portion = vector.portion;
  const exact = vector.exact;
  const hold = (holdReason) => ({ status: 'held', holdReason });

  if (!['protein_g', 'carbohydrate_g', 'fat_g', 'fiber_g', 'sodium_mg', 'energy_kcal', 'water_g'].includes(exact.attributeCode)) {
    return hold('nutrient_attribute_not_supported');
  }
  if (vector.sourceSystem.trim().toLowerCase() !== 'foundation') {
    return hold('source_data_type_not_foundation');
  }
  if (portion.sourceFoodId !== vector.sourceFoodCode) {
    return hold('portion_source_food_mismatch');
  }
  if (!Number.isFinite(portion.gramWeight) || portion.gramWeight <= 0) {
    return hold('portion_gram_weight_not_positive_finite');
  }
  if (!portion.recordLocator.startsWith(`${vector.sourceFoodCode}:foodPortions:`)) {
    return hold('portion_record_identity_invalid');
  }
  if (portion.sourceDocId !== exact.sourceDocId) {
    return hold('exact_nutrient_evidence_not_bound');
  }
  if (vector.sourceDocument.sourceFamily.toUpperCase() !== 'FDC' ||
      vector.sourceDocument.organization.toLowerCase() !== 'usda' ||
      vector.sourceDocument.jurisdiction.toUpperCase() !== 'US' ||
      vector.sourceDocument.resolutionStatus !== 'resolved' ||
      vector.sourceDocument.storedPayloadPresent !== true ||
      !/^[0-9a-f]{64}$/.test(vector.sourceDocument.payloadSha256)) {
    return hold('source_document_not_resolved_usda_fdc');
  }
  const expectedUnit = exact.attributeCode.endsWith('_mg') ? 'mg' : exact.attributeCode.endsWith('_kcal') ? 'kcal' : 'g';
  if (exact.domain !== 'food' || exact.entityType !== 'food_variant' || !exact.entityKey ||
      !exact.selected || exact.qualifierKind !== 'exact' ||
      !['numeric', 'numeric_interval'].includes(exact.valueType) ||
      !Number.isFinite(exact.valueNum) || exact.valueNum < 0 ||
      exact.low !== exact.valueNum || exact.high !== exact.valueNum ||
      exact.sourceDocId !== portion.sourceDocId || !exact.scopeHash ||
      !exact.recordLocator.startsWith(`${vector.sourceFoodCode}:`) ||
      exact.basisType !== 'per_100g_edible_part' || exact.basisAmount !== 100 ||
      exact.unit.trim().toLowerCase() !== expectedUnit) {
    return hold('exact_nutrient_evidence_not_bound');
  }

  let range = null;
  if (vector.range !== null) {
    const row = vector.range;
    const compatible = row.domain === exact.domain && row.entityType === exact.entityType &&
      row.entityKey === exact.entityKey && row.attributeCode === exact.attributeCode &&
      row.sourceDocId === exact.sourceDocId && row.scopeHash === exact.scopeHash &&
      row.unit === exact.unit && row.basisType === exact.basisType &&
      row.basisAmount === exact.basisAmount && row.methodCode === exact.methodCode &&
      row.valueType === 'numeric_interval' && row.qualifierKind === 'range' &&
      row.recordLocator === `${vector.sourceFoodCode}:${exact.attributeCode}:sample_range`;
    if (!compatible) return hold('sample_range_evidence_not_uniquely_bound');
    if (!Number.isFinite(row.low) || !Number.isFinite(row.high) || row.low < 0 ||
        row.high < row.low || exact.valueNum < row.low || exact.valueNum > row.high) {
      return hold('sample_range_bounds_invalid_or_exclude_point');
    }
    range = row;
  }

  const ratio = portion.gramWeight / 100;
  const perPortionValue = exact.valueNum * ratio;
  const result = { status: 'calculated_preview', perPortionValue };
  if (range !== null) {
    result.sourceSampleMinimumPerPortion = range.low * ratio;
    result.sourceSampleMaximumPerPortion = range.high * ratio;
  }
  if (![ratio, perPortionValue, result.sourceSampleMinimumPerPortion, result.sourceSampleMaximumPerPortion]
    .filter((value) => value !== undefined).every(Number.isFinite)) {
    return hold('portion_composition_result_not_finite');
  }
  return result;
}
