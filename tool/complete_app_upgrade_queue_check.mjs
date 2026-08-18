#!/usr/bin/env node

import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export const QUEUE_PATH = 'config/complete_app_upgrade_queue.json';

const ALLOWED_STATUSES = new Set([
  'shipped',
  'in_progress',
  'queued',
  'research_required',
  'external_dependency',
]);
const ALLOWED_PRIORITIES = new Set(['P0', 'P1', 'P2', 'P3']);

export function validateUpgradeQueue(queue) {
  const failures = [];
  if (queue?.schemaVersion !== 1) failures.push('schemaVersion must equal 1');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(queue?.reviewedAt ?? '')) {
    failures.push('reviewedAt must use YYYY-MM-DD');
  }
  if (!String(queue?.boundary ?? '').includes('clinical validation')) {
    failures.push('boundary must explicitly deny implied clinical validation');
  }
  if (!Array.isArray(queue?.items) || queue.items.length === 0) {
    failures.push('items must be a non-empty array');
    return failures;
  }

  const ids = new Set();
  const dependencyMap = new Map();
  let inProgressCount = 0;
  for (const item of queue.items) {
    const id = String(item?.id ?? '');
    if (!/^[a-z][a-z0-9_]+$/.test(id)) failures.push(`invalid item id: ${id}`);
    if (ids.has(id)) failures.push(`duplicate item id: ${id}`);
    ids.add(id);

    if (!ALLOWED_STATUSES.has(item.status)) {
      failures.push(`${id} has invalid status: ${item.status}`);
    }
    if (item.status === 'in_progress') inProgressCount += 1;
    if (!ALLOWED_PRIORITIES.has(item.priority)) {
      failures.push(`${id} has invalid priority: ${item.priority}`);
    }

    for (const field of ['impact', 'risk', 'effort']) {
      if (!Number.isInteger(item[field]) || item[field] < 1 || item[field] > 5) {
        failures.push(`${id} ${field} must be an integer from 1 to 5`);
      }
    }
    const expectedScore =
      (Number(item.impact) + Number(item.risk)) * (6 - Number(item.effort));
    if (item.score !== expectedScore) {
      failures.push(`${id} score ${item.score} does not match ${expectedScore}`);
    }
    if (!String(item.currentGap ?? '').trim()) {
      failures.push(`${id} currentGap is required`);
    }
    if (!Array.isArray(item.acceptanceCriteria) || item.acceptanceCriteria.length < 2) {
      failures.push(`${id} needs at least two acceptance criteria`);
    }
    if (!Array.isArray(item.evidenceUrls)) {
      failures.push(`${id} evidenceUrls must be an array`);
    } else {
      for (const url of item.evidenceUrls) {
        if (!/^https:\/\//.test(url)) failures.push(`${id} evidence URL is not HTTPS: ${url}`);
      }
    }
    if (!Array.isArray(item.dependencies)) {
      failures.push(`${id} dependencies must be an array`);
    } else {
      dependencyMap.set(id, item.dependencies);
    }
  }

  if (inProgressCount > 3) {
    failures.push(`at most three items may be in_progress; found ${inProgressCount}`);
  }
  for (const [id, dependencies] of dependencyMap.entries()) {
    for (const dependency of dependencies) {
      if (!ids.has(dependency)) failures.push(`${id} has unknown dependency: ${dependency}`);
      if (dependency === id) failures.push(`${id} cannot depend on itself`);
    }
  }

  const visiting = new Set();
  const visited = new Set();
  const visit = (id) => {
    if (visiting.has(id)) {
      failures.push(`dependency cycle reaches ${id}`);
      return;
    }
    if (visited.has(id)) return;
    visiting.add(id);
    for (const dependency of dependencyMap.get(id) ?? []) {
      if (ids.has(dependency)) visit(dependency);
    }
    visiting.delete(id);
    visited.add(id);
  };
  for (const id of ids) visit(id);
  return [...new Set(failures)];
}

export function readAndValidateUpgradeQueue(path = QUEUE_PATH) {
  const queue = JSON.parse(fs.readFileSync(path, 'utf8'));
  return { queue, failures: validateUpgradeQueue(queue) };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const { queue, failures } = readAndValidateUpgradeQueue();
  if (failures.length > 0) {
    for (const failure of failures) process.stderr.write(`FAIL ${failure}\n`);
    process.exit(1);
  }
  const counts = Object.groupBy(queue.items, (item) => item.status);
  process.stdout.write(
    `Complete-app upgrade queue passed: ${queue.items.length} items, ` +
      `${counts.in_progress?.length ?? 0} in progress, ` +
      `${counts.queued?.length ?? 0} queued, ` +
      `${counts.research_required?.length ?? 0} research, ` +
      `${counts.external_dependency?.length ?? 0} external dependency\n`,
  );
}
