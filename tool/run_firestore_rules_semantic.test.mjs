import assert from 'node:assert/strict';
import test from 'node:test';

import {
  chooseJava21,
  firebaseEmulatorInvocation,
  parseJavaMajor,
} from './run_firestore_rules_semantic.mjs';

test('parses modern and legacy Java version strings', () => {
  assert.equal(parseJavaMajor('openjdk version "21.0.9" 2025-10-21'), 21);
  assert.equal(parseJavaMajor('java version "1.8.0_471"'), 8);
  assert.equal(parseJavaMajor('openjdk version "17.0.12"'), 17);
  assert.equal(parseJavaMajor('not a Java version'), null);
});

test('selects the first Java 21+ runtime after rejecting older candidates', () => {
  const candidates = [
    { home: '/jdk8', executable: '/jdk8/bin/java' },
    { home: '/jdk21', executable: '/jdk21/bin/java' },
    { home: '/jdk22', executable: '/jdk22/bin/java' },
  ];
  const majors = new Map([
    ['/jdk8/bin/java', 8],
    ['/jdk21/bin/java', 21],
    ['/jdk22/bin/java', 22],
  ]);

  assert.deepEqual(
    chooseJava21(candidates, (candidate) => ({
      major: majors.get(candidate.executable),
    })),
    {
      home: '/jdk21',
      executable: '/jdk21/bin/java',
      major: 21,
    },
  );
});

test('fails closed when no runtime meets the emulator minimum', () => {
  const candidates = [
    { home: '/jdk8', executable: '/jdk8/bin/java' },
    { home: '/jdk17', executable: '/jdk17/bin/java' },
  ];
  assert.equal(
    chooseJava21(candidates, (candidate) => ({
      major: candidate.home === '/jdk8' ? 8 : 17,
    })),
    null,
  );
});

test('launches Firebase through Node without shell parsing checkout paths', () => {
  const invocation = firebaseEmulatorInvocation({
    root: String.raw`C:\work tree\ParkinSUM & review`,
    nodeExecutable: String.raw`C:\Program Files\nodejs\node.exe`,
  });

  assert.equal(invocation.shell, false);
  assert.equal(
    invocation.executable,
    String.raw`C:\Program Files\nodejs\node.exe`,
  );
  assert.equal(invocation.args[0], invocation.cliEntrypoint);
  assert.match(invocation.cliEntrypoint, /ParkinSUM & review/);
  assert.equal(
    invocation.args.at(-1),
    'node tool/run_firestore_rules_semantic_suite.mjs',
  );
});
