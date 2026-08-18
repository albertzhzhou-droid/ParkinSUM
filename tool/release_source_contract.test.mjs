import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  formatSourceContractLines,
  inspectReleaseSource,
} from './release_source_contract.mjs';

function git(cwd, args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
}

function makeRepository() {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'parkinsum-release-source-'));
  git(cwd, ['init', '-q']);
  git(cwd, ['config', 'user.email', 'release-test@example.invalid']);
  git(cwd, ['config', 'user.name', 'Release Test']);
  fs.writeFileSync(path.join(cwd, '.gitignore'), '.env\n');
  fs.writeFileSync(path.join(cwd, 'tracked.txt'), 'committed\n');
  git(cwd, ['add', '.gitignore', 'tracked.txt']);
  git(cwd, ['commit', '-qm', 'fixture']);
  return cwd;
}

test('clean stage/prod source resolves immutable commit and tree', () => {
  const cwd = makeRepository();
  const source = inspectReleaseSource({ cwd, environment: 'prod' });

  assert.equal(source.clean, true);
  assert.match(source.commit, /^[a-f0-9]{40}$/);
  assert.match(source.tree, /^[a-f0-9]{40}$/);
  assert.equal(
    formatSourceContractLines(source).split('\n').length,
    3,
  );
});

test('stage and prod reject tracked or untracked worktree changes', () => {
  const tracked = makeRepository();
  fs.appendFileSync(path.join(tracked, 'tracked.txt'), 'work in progress\n');
  assert.throws(
    () => inspectReleaseSource({ cwd: tracked, environment: 'stage' }),
    /require a clean tracked and untracked worktree/,
  );

  const untracked = makeRepository();
  fs.writeFileSync(path.join(untracked, 'untracked.txt'), 'private draft\n');
  assert.throws(
    () => inspectReleaseSource({ cwd: untracked, environment: 'prod' }),
    /require a clean tracked and untracked worktree/,
  );
});

test('dev reports a dirty tree without claiming it is the archive source', () => {
  const cwd = makeRepository();
  fs.writeFileSync(path.join(cwd, 'untracked.txt'), 'local-only\n');

  const source = inspectReleaseSource({ cwd, environment: 'dev' });

  assert.equal(source.clean, false);
  assert.equal(source.commit, git(cwd, ['rev-parse', 'HEAD']));
});

test('git archive excludes ignored secrets, untracked files, and git metadata', () => {
  const cwd = makeRepository();
  fs.writeFileSync(path.join(cwd, '.env'), 'SECRET=must-not-ship\n');
  fs.writeFileSync(path.join(cwd, 'untracked.txt'), 'must-not-ship\n');
  const archive = path.join(cwd, 'release.tar.gz');
  const source = inspectReleaseSource({ cwd, environment: 'dev' });

  git(cwd, [
    'archive',
    '--format=tar.gz',
    `--output=${archive}`,
    source.commit,
  ]);
  const members = execFileSync('tar', ['-tzf', archive], {
    encoding: 'utf8',
  }).split('\n');

  assert(members.includes('tracked.txt'));
  assert(!members.includes('.env'));
  assert(!members.includes('untracked.txt'));
  assert(!members.some((member) => member.startsWith('.git/')));
});
