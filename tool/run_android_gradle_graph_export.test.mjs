import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import test from 'node:test';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import {
  androidGradleGraphInvocation,
  chooseJava17,
  parseJavaMajor,
  resolveGradleJava17,
} from './run_android_gradle_graph_export.mjs';

const projectRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

test('parses legacy and modern Java version output', () => {
  assert.equal(parseJavaMajor('java version "1.8.0_471"'), 8);
  assert.equal(parseJavaMajor('openjdk version "17.0.12" 2024-07-16'), 17);
  assert.equal(parseJavaMajor('openjdk version "21.0.7" 2025-04-15'), 21);
  assert.equal(parseJavaMajor('not Java version output'), null);
});

test('skips runtimes below the Gradle minimum', () => {
  const runtime = chooseJava17([
    { home: '/jdk8', executable: '/jdk8/bin/java' },
    { home: '/jdk17', executable: '/jdk17/bin/java' },
    { home: '/jdk21', executable: '/jdk21/bin/java' },
  ], (candidate) => ({ major: Number(candidate.home.match(/\d+$/)[0]) }));
  assert.equal(runtime.home, '/jdk17');
  assert.equal(chooseJava17([{ home: '/jdk8' }], () => ({ major: 8 })), null);
});

test('pins the graph export task and repository-local output path', () => {
  const invocation = androidGradleGraphInvocation('/workspace/project', 'darwin');
  assert.equal(invocation.executable, path.join('/workspace/project', 'android', 'gradlew'));
  assert.equal(invocation.cwd, path.join('/workspace/project', 'android'));
  assert.equal(invocation.shell, false);
  assert.deepEqual(invocation.args, [
    '--offline',
    '--no-daemon',
    '--init-script',
    '../tool/export_android_gradle_dependency_graph.init.gradle',
    '-PparkinsumOutput=../build/open_source_release_evidence/android_gradle_debug_runtime_graph.json',
    ':exportParkinSUMAndroidDebugRuntimeGraph',
    '--console=plain',
  ]);
});

test('production Gradle scanner hashes direct and nested archive license paths', () => {
  const runtime = resolveGradleJava17();
  assert.ok(runtime, 'the scanner integration test requires Java 17 or later');

  const fixtureRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'parkinsum-archive-license-scan-'),
  );
  try {
    fs.writeFileSync(
      path.join(fixtureRoot, 'settings.gradle'),
      "rootProject.name = 'archive-license-scan-fixture'\n",
    );
    const gradleRoot = path.join(projectRoot, 'android');
    const gradlew = path.join(
      gradleRoot,
      process.platform === 'win32' ? 'gradlew.bat' : 'gradlew',
    );
    const environment = { ...process.env };
    if (runtime.home) {
      environment.JAVA_HOME = runtime.home;
      environment.PATH = `${path.join(runtime.home, 'bin')}${path.delimiter}${environment.PATH ?? ''}`;
    }
    const result = spawnSync(
      gradlew,
      [
        '--offline',
        '--no-daemon',
        '-p',
        fixtureRoot,
        '--init-script',
        path.join(
          projectRoot,
          'tool/export_android_gradle_dependency_graph.init.gradle',
        ),
        ':verifyParkinSUMAndroidArchiveLicenseScanner',
        '--console=plain',
      ],
      {
        cwd: gradleRoot,
        encoding: 'utf8',
        env: environment,
        shell: process.platform === 'win32',
        timeout: 90_000,
      },
    );
    assert.ifError(result.error);
    assert.equal(
      result.status,
      0,
      `${result.stdout ?? ''}\n${result.stderr ?? ''}`,
    );
    assert.match(
      `${result.stdout ?? ''}\n${result.stderr ?? ''}`,
      /Verified direct and nested archive-member license document paths and digests\./,
    );
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
});
