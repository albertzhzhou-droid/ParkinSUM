#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export function inspectReleaseSource({ cwd = process.cwd(), environment }) {
  if (!['dev', 'stage', 'prod'].includes(environment)) {
    throw new Error(`Unsupported release environment: ${environment}`);
  }

  const commit = git(cwd, ['rev-parse', '--verify', 'HEAD']);
  const tree = git(cwd, ['rev-parse', '--verify', 'HEAD^{tree}']);
  const status = git(cwd, [
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
    '--ignore-submodules=none',
  ]);
  const clean = status.length === 0;

  if (!clean && environment !== 'dev') {
    throw new Error(
      `${environment} releases require a clean tracked and untracked worktree. ` +
        'Commit or remove local changes before building the release.',
    );
  }

  return { commit, tree, clean };
}

export function formatSourceContractLines(source) {
  return [
    `SOURCE_GIT_COMMIT=${source.commit}`,
    `SOURCE_GIT_TREE=${source.tree}`,
    `SOURCE_GIT_CLEAN=${source.clean}`,
  ].join('\n');
}

function git(cwd, args) {
  try {
    return execFileSync('git', args, {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch (error) {
    const detail = String(error.stderr ?? error.message).trim();
    throw new Error(`Unable to inspect release Git source: ${detail}`);
  }
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const value = argv[index + 1];
    if (value == null || value.startsWith('--')) {
      parsed[key] = true;
    } else {
      parsed[key] = value;
      index += 1;
    }
  }
  return parsed;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  try {
    const source = inspectReleaseSource({
      cwd: args.cwd ?? process.cwd(),
      environment: args.env ?? process.env.PARKINSUM_ENV ?? 'prod',
    });
    process.stdout.write(`${formatSourceContractLines(source)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 2;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
