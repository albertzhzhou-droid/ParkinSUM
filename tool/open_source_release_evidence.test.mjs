import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { gzipSync } from 'node:zlib';
import { pathToFileURL } from 'node:url';

import {
  buildOpenSourceReleaseEvidence,
  parseFlutterAdditionalLicensePaths,
  parsePubspecLock,
} from './open_source_release_evidence.mjs';

function fixture() {
  const root = mkdtempSync(path.join(os.tmpdir(), 'parkinsum-open-source-evidence-'));
  const webDirectory = path.join(root, 'build/web');
  const apkPath = path.join(root, 'build/app.apk');
  const flutterSdkRoot = path.join(root, '.flutter-sdk');
  const flutterPackageRoot = path.join(flutterSdkRoot, 'packages/flutter');
  const androidGradleGraphPath = path.join(
    root,
    'build/open_source_release_evidence/android_gradle_debug_runtime_graph.json',
  );
  mkdirSync(path.join(webDirectory, 'assets'), { recursive: true });
  mkdirSync(path.dirname(apkPath), { recursive: true });
  const alphaLicense = 'Alpha package license text.';
  const betaLicense = 'Beta package license text.';
  const flutterLicense = 'Flutter SDK package license text.';
  const testLicense = 'Test-only license text.';
  const projectAdditionalLicense = 'Project additional license text.';
  const alphaAdditionalLicense = 'Alpha additional license text.';
  const licenseSeparator = `\n${'-'.repeat(80)}\n`;
  const notices = Buffer.from([
    ...[
      `alpha\n\n${alphaLicense}`,
      `beta\n\n${betaLicense}`,
      `flutter\n\n${flutterLicense}`,
      `test_tools\n\n${testLicense}`,
    ].sort(),
    projectAdditionalLicense,
    alphaAdditionalLicense,
  ].join(licenseSeparator), 'utf8');
  writeFileSync(path.join(webDirectory, 'assets/NOTICES'), notices);
  writeFileSync(path.join(webDirectory, 'index.html'), '<main>ParkinSUM</main>');
  writeFileSync(apkPath, Buffer.from('synthetic APK placeholder'));
  mkdirSync(path.join(root, 'config'), { recursive: true });
  mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
  mkdirSync(path.join(root, '.github/workflows'), { recursive: true });
  mkdirSync(path.join(root, 'assets'), { recursive: true });
  writeFileSync(path.join(root, 'pubspec.yaml'), [
    'name: parkinsum_companion',
    'version: 0.2.0+2',
    'flutter:',
    '  licenses:',
    '    - assets/project-license.txt',
    '',
  ].join('\n'));
  writeFileSync(path.join(root, 'assets/project-license.txt'), projectAdditionalLicense);
  writeFileSync(path.join(root, '.github/workflows/ci.yml'), "      - uses: subosito/flutter-action@v2\n        with:\n          flutter-version: '3.47.0'\n");
  const packageRoots = new Map([
    ['parkinsum_companion', root],
    ...['alpha', 'beta', 'test_tools'].map((name) => [
    name,
    path.join(root, '.pub-cache', name),
    ]),
    ['flutter', flutterPackageRoot],
  ]);
  for (const packageRoot of packageRoots.values()) mkdirSync(packageRoot, { recursive: true });
  mkdirSync(path.join(packageRoots.get('alpha'), 'assets'), { recursive: true });
  writeFileSync(path.join(packageRoots.get('alpha'), 'pubspec.yaml'), [
    'name: alpha',
    'version: 1.2.3',
    'flutter:',
    '  licenses:',
    '    - assets/alpha-license.txt',
    '',
  ].join('\n'));
  writeFileSync(path.join(packageRoots.get('beta'), 'pubspec.yaml'), 'name: beta\nversion: 2.0.0\n');
  writeFileSync(path.join(packageRoots.get('test_tools'), 'pubspec.yaml'), [
    'name: test_tools',
    'version: 0.1.0',
    'flutter:',
    '  licenses:',
    '    - missing-dev-only-license.txt',
    '',
  ].join('\n'));
  writeFileSync(path.join(packageRoots.get('flutter'), 'pubspec.yaml'), 'name: flutter\n');
  writeFileSync(path.join(packageRoots.get('alpha'), 'LICENSE'), alphaLicense);
  writeFileSync(path.join(packageRoots.get('beta'), 'LICENSE'), betaLicense);
  writeFileSync(path.join(packageRoots.get('test_tools'), 'LICENSE'), testLicense);
  writeFileSync(path.join(packageRoots.get('flutter'), 'LICENSE'), flutterLicense);
  writeFileSync(path.join(packageRoots.get('alpha'), 'assets/alpha-license.txt'), alphaAdditionalLicense);
  writeFileSync(
    path.join(root, '.dart_tool/package_config.json'),
    JSON.stringify({
      configVersion: 2,
      packages: [...packageRoots.entries()].map(([name, packageRoot]) => ({
        name,
        rootUri: pathToFileURL(`${packageRoot}${path.sep}`).href,
        packageUri: 'lib/',
      })),
    }),
  );
  writeFileSync(
    path.join(root, 'config/open_source_influence_inventory.json'),
    JSON.stringify({
      $schema:
        'https://parkinsum.app/schemas/open-source-influence-inventory/v7',
      schemaVersion: 7,
      releaseBoundary: { licenseNoticeMechanism: 'flutter_generated_license_bundle' },
    }),
  );
  writeFileSync(
    path.join(root, 'config/schema_catalog.json'),
    JSON.stringify({
      schemas: [{
        id: 'parkinsum.open-source-release-evidence',
        currentVersion: 3,
        source: 'lib/domain/entities/product_upgrade_queue.dart',
      }, {
        id: 'parkinsum.android-gradle-runtime-dependency-graph',
        currentVersion: 2,
        source: 'lib/domain/entities/product_upgrade_queue.dart',
      }],
    }),
  );
  writeFileSync(
    path.join(root, 'pubspec.lock'),
    `packages:\n  alpha:\n    dependency: "direct main"\n    description:\n      name: alpha\n      sha256: "${'a'.repeat(64)}"\n      url: "https://pub.dev"\n    source: hosted\n    version: "1.2.3"\n  beta:\n    dependency: transitive\n    description:\n      name: beta\n      sha256: "${'b'.repeat(64)}"\n      url: "https://pub.dev"\n    source: hosted\n    version: "2.0.0"\n  flutter:\n    dependency: "direct main"\n    source: sdk\n    version: "0.0.0"\n  test_tools:\n    dependency: "direct dev"\n    description:\n      name: test_tools\n      sha256: "${'c'.repeat(64)}"\n      url: "https://pub.dev"\n    source: hosted\n    version: "0.1.0"\n`,
  );
  writeFileSync(
    path.join(root, '.dart_tool/package_graph.json'),
    JSON.stringify({
      roots: ['parkinsum_companion'],
      packages: [
        {
      name: 'parkinsum_companion',
      version: '0.2.0+2',
          dependencies: ['alpha', 'flutter'],
          devDependencies: ['test_tools'],
        },
        { name: 'alpha', version: '1.2.3', dependencies: ['beta'] },
        { name: 'beta', version: '2.0.0', dependencies: [] },
        { name: 'test_tools', version: '0.1.0', dependencies: [] },
        { name: 'flutter', version: '0.0.0', dependencies: [] },
      ],
      configVersion: 1,
    }),
  );
  writeFileSync(
    path.join(root, '.flutter-plugins-dependencies'),
    JSON.stringify({ plugins: { android: [{ name: 'alpha', path: '/synthetic/pub-cache/alpha' }] } }),
  );
  const nativeArtifact = Buffer.from('synthetic Android core AAR');
  const embeddedLicense = Buffer.from('Synthetic embedded license document bytes.');
  mkdirSync(path.dirname(androidGradleGraphPath), { recursive: true });
  writeFileSync(
    androidGradleGraphPath,
    JSON.stringify({
      schemaUri: 'parkinsum.android-gradle-runtime-dependency-graph/2',
      schemaVersion: 2,
      configuration: 'debugRuntimeClasspath',
      root: { dependencies: [{ kind: 'pub', name: 'alpha' }] },
      components: [
        {
          id: { kind: 'maven', group: 'org.example', name: 'android-core', version: '1.2.3' },
          dependencies: [],
          artifacts: [{
            fileName: 'android-core-1.2.3.aar',
            bytes: nativeArtifact.length,
            sha256: createHash('sha256').update(nativeArtifact).digest('hex'),
            licenseDocuments: [{
              archivePath: 'META-INF/LICENSE.txt',
              bytes: embeddedLicense.length,
              sha256: createHash('sha256').update(embeddedLicense).digest('hex'),
            }],
          }],
        },
        {
          id: { kind: 'pub', name: 'alpha' },
          dependencies: [{ kind: 'maven', group: 'org.example', name: 'android-core', version: '1.2.3' }],
          artifacts: [{
            fileName: 'alpha-android-debug.aar',
            bytes: nativeArtifact.length,
            sha256: createHash('sha256').update(nativeArtifact).digest('hex'),
            licenseDocuments: [],
          }],
        },
      ],
    }),
  );
  writeFileSync(path.join(root, 'package-lock.json'), '{"lockfileVersion":3}\n');

  const flutterCollectorSources = {
    'packages/flutter_tools/lib/src/license_collector.dart': 'Pinned synthetic license collector source.\n',
    'packages/flutter_tools/lib/src/asset.dart': 'Pinned synthetic asset source.\n',
    'packages/flutter_tools/lib/src/flutter_manifest.dart': 'Pinned synthetic manifest source.\n',
  };
  for (const [relativePath, contents] of Object.entries(flutterCollectorSources)) {
    const absolutePath = path.join(flutterSdkRoot, relativePath);
    mkdirSync(path.dirname(absolutePath), { recursive: true });
    writeFileSync(absolutePath, contents);
  }
  execFileSync('git', ['init', '-q'], { cwd: flutterSdkRoot });
  execFileSync('git', ['add', '.'], { cwd: flutterSdkRoot });
  execFileSync('git', [
    '-c', 'user.name=Evidence Test',
    '-c', 'user.email=evidence@example.test',
    'commit', '-qm', 'pinned synthetic Flutter SDK',
  ], { cwd: flutterSdkRoot });
  const flutterSourceRevision = execFileSync(
    'git', ['rev-parse', 'HEAD'], { cwd: flutterSdkRoot, encoding: 'utf8' },
  ).trim();
  writeFileSync(path.join(root, '.gitignore'), '.flutter-sdk/\n');
  writeFileSync(
    path.join(root, 'config/open_source_influence_inventory.json'),
    JSON.stringify({
      $schema:
        'https://parkinsum.app/schemas/open-source-influence-inventory/v7',
      schemaVersion: 7,
      releaseBoundary: {
        licenseNoticeMechanism: 'flutter_generated_license_bundle',
        linkedVersionEvidence: {
          flutter_framework: { version: '3.47.0', sourceRevision: flutterSourceRevision },
        },
      },
    }),
  );
  execFileSync('git', ['init', '-q'], { cwd: root });
  execFileSync('git', ['add', '.'], { cwd: root });
  execFileSync('git', ['-c', 'user.name=Evidence Test', '-c', 'user.email=evidence@example.test', 'commit', '--allow-empty', '-qm', 'fixture'], { cwd: root });
  return { root, webDirectory, apkPath, androidGradleGraphPath, notices };
}

function withFixture(run) {
  const value = fixture();
  try {
    run(value);
  } finally {
    rmSync(value.root, { recursive: true, force: true });
  }
}

test('root Pubspec declares each bundled font license as a Flutter NOTICE input', () => {
  const pubspec = readFileSync('pubspec.yaml', 'utf8');
  const paths = parseFlutterAdditionalLicensePaths(pubspec, 'parkinsum_companion');
  assert.deepEqual(paths, [
    'assets/fonts/OFL-Geist.txt',
    'assets/fonts/OFL-GeistMono.txt',
    'assets/fonts/OFL-SourceSerif4.txt',
  ]);
  for (const relativePath of paths) {
    assert.match(
      readFileSync(relativePath, 'utf8'),
      /SIL OPEN FONT LICENSE Version 1\.1/,
    );
  }
});

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc & 1) === 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function storedZip(entries) {
  const localRecords = [];
  const centralRecords = [];
  let localOffset = 0;
  for (const [fileName, content] of entries) {
    const name = Buffer.from(fileName, 'utf8');
    const bytes = Buffer.from(content);
    const checksum = crc32(bytes);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt32LE(checksum, 14);
    local.writeUInt32LE(bytes.length, 18);
    local.writeUInt32LE(bytes.length, 22);
    local.writeUInt16LE(name.length, 26);
    const localRecord = Buffer.concat([local, name, bytes]);
    localRecords.push(localRecord);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt32LE(checksum, 16);
    central.writeUInt32LE(bytes.length, 20);
    central.writeUInt32LE(bytes.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(localOffset, 42);
    centralRecords.push(Buffer.concat([central, name]));
    localOffset += localRecord.length;
  }
  const centralBytes = Buffer.concat(centralRecords);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralBytes.length, 12);
  end.writeUInt32LE(localOffset, 16);
  return Buffer.concat([...localRecords, centralBytes, end]);
}

function archiveReader(notices, { platformNotice = null } = {}) {
  return (_apk, entry) => {
    if (entry === 'assets/flutter_assets/NOTICES.Z') return gzipSync(notices);
    if (entry === 'META-INF/NOTICE.md' && platformNotice) return platformNotice;
    throw new Error(`missing synthetic entry ${entry}`);
  };
}

function assertCycloneDxReferencesResolve(bom) {
  assert.equal(bom.bomFormat, 'CycloneDX');
  assert.equal(bom.specVersion, '1.7');
  assert.equal(bom.version, 1);
  assert.match(
    bom.serialNumber,
    /^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
  const refs = [
    bom.metadata.component['bom-ref'],
    ...bom.components.map((component) => component['bom-ref']),
  ];
  assert.equal(new Set(refs).size, refs.length);
  const refSet = new Set(refs);
  assert.equal(new Set(bom.dependencies.map((item) => item.ref)).size, bom.dependencies.length);
  for (const dependency of bom.dependencies) {
    assert.ok(refSet.has(dependency.ref));
    assert.equal(new Set(dependency.dependsOn).size, dependency.dependsOn.length);
    for (const target of dependency.dependsOn) assert.ok(refSet.has(target));
  }
  assert.equal(bom.compositions[0].aggregate, 'incomplete');
  for (const assembly of bom.compositions[0].assemblies) assert.ok(refSet.has(assembly));
}

test('matches Flutter-generated Web and Android notices and binds build inputs', () => {
  withFixture(({ root, webDirectory, apkPath, notices }) => {
    const report = buildOpenSourceReleaseEvidence({
      root,
      webDirectory,
      androidApkPath: apkPath,
      readArchiveEntry: archiveReader(notices, {
        platformNotice: Buffer.from('Platform dependency notice'),
      }),
    });
    assert.equal(report.status, 'passed');
    assert.equal(report.platforms.web.fileCount, 2);
    assert.match(report.platforms.android.sha256, /^[a-f0-9]{64}$/);
    assert.equal(report.crossPlatformFlutterNoticeContentsMatch, true);
    assert.equal(report.androidPlatformNotice.status, 'present');
    assert.equal(report.signature.status, 'unsigned');
    assert.equal(report.sbom.status, 'partial');
    assert.equal(report.sbom.format, 'CycloneDX');
    assert.equal(report.sbom.specVersion, '1.7');
    assert.equal(report.sbom.compositionAggregate, 'incomplete');
    assert.ok(report.sbom.excluded.some((entry) => /Google CQL Go and CQF CQL JVM Gradle\/Maven tooling/.test(entry)));
    assert.equal(report.sbom.pubDependencyComponentCount, 3);
    assert.equal(report.sbom.androidGradleDependencyGraph.componentCount, 2);
    assert.equal(report.sbom.androidGradleDependencyGraph.mavenComponentCount, 1);
    assert.equal(report.sbom.androidGradleDependencyGraph.pubProjectComponentCount, 1);
    assert.equal(report.sbom.androidGradleDependencyGraph.mavenArtifactsWithLicenseDocuments, 1);
    assert.equal(report.sbom.androidGradleDependencyGraph.embeddedLicenseDocumentCount, 1);
    assert.equal(report.sbom.documents.android.componentCount, 4);
    assert.equal(report.sbom.documents.android.pubComponentCount, 3);
    assert.equal(report.sbom.documents.android.androidGradleComponentCount, 2);
    assert.equal(report.source.worktreeClean, true);
    assert.equal(report.schemaContract.currentVersion, 3);
    assert.equal(report.androidGradleGraphSchemaContract.currentVersion, 2);
    assert.equal(
      report.androidGradleGraphSchemaContract.id,
      'parkinsum.android-gradle-runtime-dependency-graph',
    );
    assert.equal(report.dependencyLocks.length, 2);
    assert.equal(report.pubPackageConfiguration.path, '.dart_tool/package_config.json');
    assert.equal(report.pubFlutterLicenseCollectorEvidence.status, 'verified_exact_reconstruction');
    assert.equal(report.pubFlutterLicenseCollectorEvidence.exactNoticeReconstructionMatch, true);
    assert.equal(report.pubFlutterLicenseCollectorEvidence.packageCount, 5);
    assert.equal(report.pubFlutterLicenseCollectorEvidence.runtimePackageCount, 3);
    assert.equal(report.pubFlutterLicenseCollectorEvidence.developmentOnlyPackageCount, 1);
    assert.equal(report.pubFlutterLicenseCollectorEvidence.runtimePackageCountWithCollectedLicenseInputs, 3);
    assert.equal(report.pubFlutterLicenseCollectorEvidence.selectedLicenseDocumentCount, 6);
    assert.deepEqual(report.pubFlutterLicenseCollectorEvidence.packagesWithoutSelectedLicenseInput, []);
    assert.match(
      report.pubFlutterLicenseCollectorEvidence.flutterLicenseCollectorSource.sourceRevision,
      /^[a-f0-9]{40}$/,
    );
    assert.match(report.statementId, /^[a-f0-9]{64}$/);
    assert.equal(report.cycloneDxDocuments.web.components.length, 3);
    assert.equal(report.cycloneDxDocuments.web.compositions[0].aggregate, 'incomplete');
    assert.deepEqual(
      report.cycloneDxDocuments.web.components.map((component) => component.name),
      ['alpha', 'beta', 'flutter'],
    );
    assert.ok(report.cycloneDxDocuments.web.components.every((component) =>
      component.properties.some((property) =>
        property.name === 'parkinsum:licenseAssertionStatus' &&
        property.value === 'NOASSERTION',
      ),
    ));
    const alphaBomComponent = report.cycloneDxDocuments.web.components.find((component) =>
      component.name === 'alpha',
    );
    assert.ok(alphaBomComponent.properties.some((property) =>
      property.name === 'parkinsum:flutterLicenseCollectorInputStatus' &&
      property.value === 'selected_by_pinned_flutter_license_collector',
    ));
    const alphaLicenseEvidence = JSON.parse(alphaBomComponent.properties.find((property) =>
      property.name === 'parkinsum:flutterLicenseCollectorSourceDocuments',
    ).value);
    assert.deepEqual(alphaLicenseEvidence.map((item) => item.path), [
      'LICENSE',
      'assets/alpha-license.txt',
    ]);
    assert.ok(alphaLicenseEvidence.every((item) => /^[a-f0-9]{64}$/.test(item.sha256)));
    assert.equal(
      report.cycloneDxDocuments.web.components.some((component) => component.name === 'test_tools'),
      false,
    );
    assert.deepEqual(
      report.cycloneDxDocuments.web.dependencies.find((item) =>
        item.ref.endsWith(':alpha@1.2.3:hosted'),
      ).dependsOn,
      ['urn:parkinsum:pub:beta@2.0.0:hosted'],
    );
    assertCycloneDxReferencesResolve(report.cycloneDxDocuments.web);
    const androidNativeComponent = report.cycloneDxDocuments.android.components.find((component) =>
      component.purl === 'pkg:maven/org.example/android-core@1.2.3',
    );
    assert.ok(androidNativeComponent);
    assert.match(androidNativeComponent.hashes[0].content, /^[a-f0-9]{64}$/);
    assert.ok(androidNativeComponent.properties.some((property) =>
      property.name === 'parkinsum:licenseAssertionStatus' && property.value === 'NOASSERTION',
    ));
    const embeddedLicenseEvidence = JSON.parse(androidNativeComponent.properties.find((property) =>
      property.name === 'parkinsum:embeddedLicenseDocumentEvidence',
    ).value);
    assert.deepEqual(embeddedLicenseEvidence.map((item) => item.archivePath), [
      'META-INF/LICENSE.txt',
    ]);
    assert.equal(embeddedLicenseEvidence[0].artifactFileName, 'android-core-1.2.3.aar');
    assert.match(embeddedLicenseEvidence[0].artifactSha256, /^[a-f0-9]{64}$/);
    assert.match(embeddedLicenseEvidence[0].sha256, /^[a-f0-9]{64}$/);
    assert.ok(report.cycloneDxDocuments.android.metadata.component.properties.some((property) =>
      property.name === 'parkinsum:androidGradleDependencyGraphSha256' &&
      property.value === report.sbom.androidGradleDependencyGraph.sha256,
    ));
    assertCycloneDxReferencesResolve(report.cycloneDxDocuments.android);
    const repeated = buildOpenSourceReleaseEvidence({
      root,
      webDirectory,
      androidApkPath: apkPath,
      readArchiveEntry: archiveReader(notices, {
        platformNotice: Buffer.from('Platform dependency notice'),
      }),
    });
    assert.equal(
      report.sbom.documents.web.contentDigest,
      repeated.sbom.documents.web.contentDigest,
    );
    assert.notEqual(
      report.sbom.documents.web.serialNumber,
      repeated.sbom.documents.web.serialNumber,
    );
  });
});

test('fails closed when NOTICE content differs between platforms', () => {
  withFixture(({ root, webDirectory, apkPath }) => {
    assert.throws(
      () => buildOpenSourceReleaseEvidence({
        root,
        webDirectory,
        androidApkPath: apkPath,
        readArchiveEntry: archiveReader(Buffer.from('different notice')),
      }),
      /contents differ/,
    );
  });
});

test('fails closed when source-selected Pub license inputs diverge from NOTICE', () => {
  withFixture(({ root, webDirectory }) => {
    writeFileSync(
      path.join(root, '.pub-cache/beta/LICENSE'),
      'Beta source license is not present in the bundle.',
    );
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
      /Flutter NOTICE does not match pinned license-collector inputs/,
    );
  });
});

test('fails closed for missing Web notice or malformed Android gzip', () => {
  withFixture(({ root, webDirectory, apkPath }) => {
    rmSync(path.join(webDirectory, 'assets/NOTICES'));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, androidApkPath: apkPath }),
      /assets\/NOTICES/,
    );
  });
  withFixture(({ root, webDirectory, apkPath }) => {
    assert.throws(
      () => buildOpenSourceReleaseEvidence({
        root,
        webDirectory,
        androidApkPath: apkPath,
        readArchiveEntry: () => Buffer.from('not gzip'),
      }),
      /not valid gzip/,
    );
  });
});

test('web-only evidence records no cross-platform comparison', () => {
  withFixture(({ root, webDirectory }) => {
    const report = buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true });
    assert.deepEqual(Object.keys(report.platforms), ['web']);
    assert.equal(report.crossPlatformFlutterNoticeContentsMatch, null);
    assert.equal(report.androidPlatformNotice, null);
  });
});

test('refuses an inventory that selects a different license-notice mechanism', () => {
  withFixture(({ root, webDirectory }) => {
    const inventoryPath = path.join(root, 'config/open_source_influence_inventory.json');
    const inventory = JSON.parse(readFileSync(inventoryPath, 'utf8'));
    inventory.releaseBoundary.licenseNoticeMechanism = 'manual';
    writeFileSync(inventoryPath, JSON.stringify(inventory));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
      /NOTICE mechanism is not supported/,
    );
  });
});

test('refuses an obsolete inventory schema URI or version', () => {
  for (const [schemaUri, schemaVersion] of [
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v5', 6],
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v6', 6],
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v7', 5],
  ]) {
    withFixture(({ root, webDirectory }) => {
      const inventoryPath = path.join(root, 'config/open_source_influence_inventory.json');
      const inventory = JSON.parse(readFileSync(inventoryPath, 'utf8'));
      inventory.$schema = schemaUri;
      inventory.schemaVersion = schemaVersion;
      writeFileSync(inventoryPath, JSON.stringify(inventory));
  assert.throws(
        () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
        /inventory schema or NOTICE mechanism is not supported/,
      );
    });
  }
});

test('Pub lock parser retains source, directness, and integrity fields', () => {
  withFixture(({ root }) => {
    const entries = parsePubspecLock(readFileSync(path.join(root, 'pubspec.lock'), 'utf8'));
    assert.deepEqual(entries.get('alpha'), {
      name: 'alpha',
      source: 'hosted',
      version: '1.2.3',
      dependency: 'direct main',
      sha256: 'a'.repeat(64),
    });
    assert.equal(entries.get('test_tools').dependency, 'direct dev');
  });
});

test('CLI writes CycloneDX files and binds their bytes to the report', () => {
  withFixture(({ root, webDirectory, apkPath, notices }) => {
    const output = 'build/evidence/report.json';
    writeFileSync(apkPath, storedZip([
      ['assets/flutter_assets/NOTICES.Z', gzipSync(notices)],
      ['META-INF/NOTICE.md', Buffer.from('Platform dependency notice')],
    ]));
    const script = path.resolve('tool/open_source_release_evidence.mjs');
    execFileSync(process.execPath, [
      script,
      '--root', root,
      '--web-dir', path.relative(root, webDirectory),
      '--android-apk', path.relative(root, apkPath),
      '--output', output,
    ], { cwd: root, stdio: 'pipe' });
    const report = JSON.parse(readFileSync(path.join(root, output), 'utf8'));
    for (const platform of ['web', 'android']) {
      const documentPath = path.join(root, report.sbom.documents[platform].path);
      const bytes = readFileSync(documentPath);
      const document = JSON.parse(bytes.toString('utf8'));
      assertCycloneDxReferencesResolve(document);
      assert.equal(
        report.sbom.documents[platform].sha256,
        createHash('sha256').update(bytes).digest('hex'),
      );
    }
  });
});

test('fails closed when a reachable package version drifts from pubspec.lock', () => {
  withFixture(({ root, webDirectory }) => {
    const graphPath = path.join(root, '.dart_tool/package_graph.json');
    const graph = JSON.parse(readFileSync(graphPath, 'utf8'));
    graph.packages.find((item) => item.name === 'alpha').version = '9.9.9';
    writeFileSync(graphPath, JSON.stringify(graph));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
      /Dart package graph and pubspec.lock disagree for alpha/,
    );
  });
});

test('fails closed when a resolved Pub root no longer matches its locked name and version', () => {
  withFixture(({ root, webDirectory }) => {
    writeFileSync(
      path.join(root, '.pub-cache/alpha/pubspec.yaml'),
      'name: alpha\nversion: 9.9.9\n',
    );
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
      /root and locked identity disagree \(alpha\)/,
    );
  });
});

test('fails closed for an unclosed or unmapped Android Gradle graph', () => {
  withFixture(({ root, webDirectory, androidGradleGraphPath, notices }) => {
    const graph = JSON.parse(readFileSync(androidGradleGraphPath, 'utf8'));
    graph.components[0].dependencies = [{ kind: 'maven', group: 'org.missing', name: 'missing', version: '1.0' }];
    writeFileSync(androidGradleGraphPath, JSON.stringify(graph));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({
        root,
        webDirectory,
        androidApkPath: path.join(root, 'build/app.apk'),
        readArchiveEntry: archiveReader(notices),
      }),
      /dangling edge/,
    );
  });
  withFixture(({ root, webDirectory, androidGradleGraphPath, notices }) => {
    const graph = JSON.parse(readFileSync(androidGradleGraphPath, 'utf8'));
    graph.components.find((component) => component.id.kind === 'pub').id.name = 'unknown_plugin';
    writeFileSync(androidGradleGraphPath, JSON.stringify(graph));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({
        root,
        webDirectory,
        androidApkPath: path.join(root, 'build/app.apk'),
        readArchiveEntry: archiveReader(notices),
      }),
      /not present in the Pub package graph/,
    );
  });
  withFixture(({ root, webDirectory, androidGradleGraphPath, notices }) => {
    const graph = JSON.parse(readFileSync(androidGradleGraphPath, 'utf8'));
    graph.components[0].artifacts[0].licenseDocuments[0].archivePath = '../LICENSE';
    writeFileSync(androidGradleGraphPath, JSON.stringify(graph));
    assert.throws(
      () => buildOpenSourceReleaseEvidence({
        root,
        webDirectory,
        androidApkPath: path.join(root, 'build/app.apk'),
        readArchiveEntry: archiveReader(notices),
      }),
      /invalid embedded license evidence/,
    );
  });
});

test('fails closed until Git and path package identities are represented', () => {
  withFixture(({ root, webDirectory }) => {
    const lockPath = path.join(root, 'pubspec.lock');
    const lock = readFileSync(lockPath, 'utf8').replace('source: hosted', 'source: git');
    writeFileSync(lockPath, lock);
    assert.throws(
      () => buildOpenSourceReleaseEvidence({ root, webDirectory, webOnly: true }),
      /does not support Pub source git \(alpha\)/,
    );
  });
});
