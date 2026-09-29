#!/usr/bin/env node

// Check Flutter's generated license notice in built release artifacts. This is
// release-hygiene evidence only: it is not a complete SBOM or legal approval.

import { execFileSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { gunzipSync } from 'node:zlib';
import { fileURLToPath, pathToFileURL } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
export const REPOSITORY_ROOT = path.dirname(path.dirname(modulePath));
export const OPEN_SOURCE_RELEASE_EVIDENCE_SCHEMA_VERSION = 3;
export const OPEN_SOURCE_RELEASE_EVIDENCE_SCHEMA_URI =
  'parkinsum.open-source-release-evidence/3';
export const OPEN_SOURCE_INFLUENCE_INVENTORY_JSON_SCHEMA_VERSION = 7;
export const OPEN_SOURCE_INFLUENCE_INVENTORY_JSON_SCHEMA_URI =
  'https://parkinsum.app/schemas/open-source-influence-inventory/v7';
export const ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_VERSION = 2;
export const ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_URI =
  'parkinsum.android-gradle-runtime-dependency-graph/2';

const FLUTTER_WEB_NOTICE_PATH = 'assets/NOTICES';
const FLUTTER_ANDROID_NOTICE_ENTRY = 'assets/flutter_assets/NOTICES.Z';
const ANDROID_PLATFORM_NOTICE_ENTRY = 'META-INF/NOTICE.md';
const DEFAULT_ANDROID_APK = 'build/app/outputs/flutter-apk/app-debug.apk';
const DEFAULT_ANDROID_GRADLE_GRAPH =
  'build/open_source_release_evidence/android_gradle_debug_runtime_graph.json';

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function readZipEntry(apkPath, entryPath) {
  try {
    return execFileSync('unzip', ['-p', apkPath, entryPath], {
      encoding: 'buffer',
      maxBuffer: 16 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    const detail = String(error.stderr ?? error.message).trim();
    throw new Error(`Unable to read ${entryPath} from Android APK: ${detail}`);
  }
}

function requiredBytes(bytes, label) {
  if (!Buffer.isBuffer(bytes) || bytes.length === 0) {
    throw new Error(`${label} is missing or empty`);
  }
  return bytes;
}

function describeBytes(bytes) {
  return { bytes: bytes.length, sha256: sha256(bytes) };
}

function listTreeFiles(directory, prefix = '') {
  if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
    throw new Error(`Built Web output directory is missing: ${directory}`);
  }
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    const relative = path.posix.join(prefix, entry.name);
    if (entry.isSymbolicLink()) {
      throw new Error(`Web build contains a symbolic link: ${relative}`);
    }
    if (entry.isDirectory()) files.push(...listTreeFiles(absolute, relative));
    else if (entry.isFile()) files.push({ absolute, relative });
    else throw new Error(`Web build contains an unsupported filesystem entry: ${relative}`);
  }
  return files;
}

function describeWebBuild(webDirectory) {
  const files = listTreeFiles(webDirectory).sort((left, right) =>
    left.relative.localeCompare(right.relative),
  );
  if (files.length === 0) throw new Error('Built Web output contains no files');
  const tree = createHash('sha256');
  for (const file of files) {
    const bytes = fs.readFileSync(file.absolute);
    tree.update(`${sha256(bytes)}  ${file.relative}\n`, 'utf8');
  }
  const noticeBytes = requiredBytes(
    fs.readFileSync(path.join(webDirectory, FLUTTER_WEB_NOTICE_PATH)),
    `Web ${FLUTTER_WEB_NOTICE_PATH}`,
  );
  return {
    artifact: {
      kind: 'flutter_web_build_tree',
      fileCount: files.length,
      sha256: tree.digest('hex'),
    },
    flutterGeneratedNotice: {
      path: FLUTTER_WEB_NOTICE_PATH,
      ...describeBytes(noticeBytes),
    },
    noticeBytes,
  };
}

function describeAndroidApk(apkPath, readEntry) {
  if (!fs.existsSync(apkPath) || !fs.statSync(apkPath).isFile()) {
    throw new Error(`Android APK is missing: ${apkPath}`);
  }
  const apkBytes = fs.readFileSync(apkPath);
  requiredBytes(apkBytes, 'Android APK');
  const compressedNotice = requiredBytes(
    readEntry(apkPath, FLUTTER_ANDROID_NOTICE_ENTRY),
    `Android ${FLUTTER_ANDROID_NOTICE_ENTRY}`,
  );
  let noticeBytes;
  try {
    noticeBytes = requiredBytes(
      gunzipSync(compressedNotice),
      'Decompressed Android Flutter NOTICE bundle',
    );
  } catch (error) {
    throw new Error(`Android Flutter NOTICE bundle is not valid gzip: ${error.message}`);
  }

  let platformNotice;
  try {
    const bytes = requiredBytes(
      readEntry(apkPath, ANDROID_PLATFORM_NOTICE_ENTRY),
      `Android ${ANDROID_PLATFORM_NOTICE_ENTRY}`,
    );
    platformNotice = {
      status: 'present',
      path: ANDROID_PLATFORM_NOTICE_ENTRY,
      ...describeBytes(bytes),
    };
  } catch {
    platformNotice = { status: 'not_present', path: ANDROID_PLATFORM_NOTICE_ENTRY };
  }

  return {
    artifact: {
      kind: 'android_apk',
      bytes: apkBytes.length,
      sha256: sha256(apkBytes),
    },
    flutterGeneratedNotice: {
      path: FLUTTER_ANDROID_NOTICE_ENTRY,
      archiveEntry: describeBytes(compressedNotice),
      decompressed: describeBytes(noticeBytes),
    },
    platformNotice,
    noticeBytes,
  };
}

function readSourceAndInventory(root) {
  const inventoryPath = path.join(root, 'config/open_source_influence_inventory.json');
  const inventoryBytes = fs.readFileSync(inventoryPath);
  const inventory = JSON.parse(inventoryBytes.toString('utf8'));
  if (
    inventory?.$schema !== OPEN_SOURCE_INFLUENCE_INVENTORY_JSON_SCHEMA_URI ||
    inventory?.schemaVersion !== OPEN_SOURCE_INFLUENCE_INVENTORY_JSON_SCHEMA_VERSION ||
    inventory?.releaseBoundary?.licenseNoticeMechanism !==
      'flutter_generated_license_bundle'
  ) {
    throw new Error(
      'Open-source influence inventory schema or NOTICE mechanism is not supported',
    );
  }

  const schemaCatalogPath = path.join(root, 'config/schema_catalog.json');
  const schemaCatalogBytes = fs.readFileSync(schemaCatalogPath);
  const schemaCatalog = JSON.parse(schemaCatalogBytes.toString('utf8'));
  const schemaContract = schemaCatalog.schemas?.find(
    (candidate) => candidate.id === 'parkinsum.open-source-release-evidence',
  );
  if (
    schemaContract?.currentVersion !== OPEN_SOURCE_RELEASE_EVIDENCE_SCHEMA_VERSION ||
    schemaContract?.source !== 'lib/domain/entities/product_upgrade_queue.dart'
  ) {
    throw new Error('Open-source release evidence schema is missing or out of sync with the catalog');
  }
  const androidGraphSchemaContract = schemaCatalog.schemas?.find(
    (candidate) => candidate.id === 'parkinsum.android-gradle-runtime-dependency-graph',
  );
  if (
    androidGraphSchemaContract?.currentVersion !== ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_VERSION ||
    androidGraphSchemaContract?.source !== 'lib/domain/entities/product_upgrade_queue.dart'
  ) {
    throw new Error('Android Gradle dependency graph schema is missing or out of sync with the catalog');
  }

  const dependencyLocks = ['pubspec.lock', 'package-lock.json'].map((relativePath) => {
    const bytes = fs.readFileSync(path.join(root, relativePath));
    return { path: relativePath, ...describeBytes(bytes) };
  });
  const packageConfigurationPath = path.join(root, '.dart_tool/package_config.json');
  const packageConfigurationBytes = fs.readFileSync(packageConfigurationPath);
  const pubLockBytes = fs.readFileSync(path.join(root, 'pubspec.lock'));
  const packageGraphPath = path.join(root, '.dart_tool/package_graph.json');
  const packageGraphBytes = fs.readFileSync(packageGraphPath);
  const packageGraph = JSON.parse(packageGraphBytes.toString('utf8'));
  const lockedPackages = parsePubspecLock(pubLockBytes.toString('utf8'));
  const runtimePubInventory = buildRuntimePubInventory(packageGraph, lockedPackages);

  let source;
  try {
    const commit = execFileSync('git', ['rev-parse', '--verify', 'HEAD'], {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    const tree = execFileSync('git', ['rev-parse', '--verify', 'HEAD^{tree}'], {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
    const status = execFileSync(
      'git',
      ['status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none'],
      { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
    );
    source = { commit, tree, worktreeClean: status.length === 0 };
  } catch {
    source = { commit: null, tree: null, worktreeClean: null };
  }

  return {
    source,
    inventory: {
      path: path.relative(root, inventoryPath).split(path.sep).join('/'),
      schemaVersion: inventory.schemaVersion,
      sha256: sha256(inventoryBytes),
    },
    schemaContract: {
      id: schemaContract.id,
      currentVersion: schemaContract.currentVersion,
      source: schemaContract.source,
      catalogPath: path.relative(root, schemaCatalogPath).split(path.sep).join('/'),
      catalogSha256: sha256(schemaCatalogBytes),
    },
    flutterToolchain: inventory.releaseBoundary?.linkedVersionEvidence?.flutter_framework ?? null,
    androidGraphSchemaContract: {
      id: androidGraphSchemaContract.id,
      currentVersion: androidGraphSchemaContract.currentVersion,
      source: androidGraphSchemaContract.source,
      catalogPath: path.relative(root, schemaCatalogPath).split(path.sep).join('/'),
      catalogSha256: sha256(schemaCatalogBytes),
    },
    dependencyLocks,
    packageConfiguration: {
      path: path.relative(root, packageConfigurationPath).split(path.sep).join('/'),
      ...describeBytes(packageConfigurationBytes),
    },
    packageGraph: {
      path: path.relative(root, packageGraphPath).split(path.sep).join('/'),
      sha256: sha256(packageGraphBytes),
      runtimePubInventory,
    },
  };
}

function unquoteYamlScalar(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

export function parsePubspecLock(lockText) {
  if (typeof lockText !== 'string' || !/^packages:\s*$/m.test(lockText)) {
    throw new Error('pubspec.lock is missing the packages mapping');
  }
  const entries = new Map();
  let current = null;
  const finish = () => {
    if (current === null) return;
    if (!current.version || !['hosted', 'git', 'path', 'sdk'].includes(current.source)) {
      throw new Error(`pubspec.lock entry ${current.name} is missing version or source`);
    }
    if (entries.has(current.name)) {
      throw new Error(`pubspec.lock contains duplicate package ${current.name}`);
    }
    if (current.source === 'hosted' && current.sha256 === null) {
      throw new Error(`hosted pubspec.lock entry ${current.name} is missing its SHA-256`);
    }
    entries.set(current.name, current);
  };

  for (const line of lockText.split(/\r?\n/)) {
    const header = line.match(/^  ([A-Za-z0-9_-]+):\s*$/);
    if (header) {
      finish();
      current = { name: header[1], source: null, version: null, dependency: null, sha256: null };
      continue;
    }
    if (current === null) continue;
    let match = line.match(/^    source:\s*(\S+)\s*$/);
    if (match) current.source = unquoteYamlScalar(match[1]);
    match = line.match(/^    version:\s*(.*?)\s*$/);
    if (match) current.version = unquoteYamlScalar(match[1]);
    match = line.match(/^    dependency:\s*(.*?)\s*$/);
    if (match) current.dependency = unquoteYamlScalar(match[1]);
    match = line.match(/^\s+sha256:\s*["']?([a-f0-9]{64})["']?\s*$/i);
    if (match) current.sha256 = match[1].toLowerCase();
  }
  finish();
  if (entries.size === 0) throw new Error('pubspec.lock contains no package entries');
  return entries;
}

function buildRuntimePubInventory(packageGraph, lockedPackages) {
  if (
    !packageGraph ||
    !Array.isArray(packageGraph.roots) ||
    packageGraph.roots.length !== 1 ||
    !Array.isArray(packageGraph.packages)
  ) {
    throw new Error('Dart package graph must have one root and a packages array');
  }
  const packagesByName = new Map();
  for (const item of packageGraph.packages) {
    if (
      !item ||
      typeof item.name !== 'string' ||
      typeof item.version !== 'string' ||
      !Array.isArray(item.dependencies) ||
      packagesByName.has(item.name)
    ) {
      throw new Error('Dart package graph has an invalid or duplicate package entry');
    }
    packagesByName.set(item.name, item);
  }
  const root = packagesByName.get(packageGraph.roots[0]);
  if (!root || !Array.isArray(root.devDependencies)) {
    throw new Error('Dart package graph root is missing devDependencies metadata');
  }

  const allPackages = [...packagesByName.keys()]
    .filter((name) => name !== root.name)
    .sort((left, right) => left.localeCompare(right))
    .map((name) => {
      const item = packagesByName.get(name);
      const lockEntry = lockedPackages.get(name);
      if (!lockEntry || lockEntry.version !== item.version) {
        throw new Error(`Dart package graph and pubspec.lock disagree for ${name}`);
      }
      return {
        name,
        version: item.version,
        dependencies: [...new Set(item.dependencies)]
          .filter((dependency) => dependency !== root.name)
          .sort((left, right) => left.localeCompare(right)),
        source: lockEntry.source,
        lockDependency: lockEntry.dependency,
        sha256: lockEntry.sha256,
      };
    });
  const allPackagesByName = new Map(allPackages.map((item) => [item.name, item]));

  const reachable = new Set();
  const pending = [...root.dependencies];
  while (pending.length > 0) {
    const name = pending.pop();
    if (name === root.name || reachable.has(name)) continue;
    const item = packagesByName.get(name);
    if (!item) throw new Error(`Dart package graph references missing package ${name}`);
    const lockEntry = lockedPackages.get(name);
    if (!lockEntry || lockEntry.version !== item.version) {
      throw new Error(`Dart package graph and pubspec.lock disagree for ${name}`);
    }
    if (!['hosted', 'sdk'].includes(lockEntry.source)) {
      throw new Error(`CycloneDX component identity does not support Pub source ${lockEntry.source} (${name})`);
    }
    reachable.add(name);
    pending.push(...item.dependencies);
  }

  const runtimePackages = [...reachable].sort((left, right) => left.localeCompare(right));
  return {
    root,
    packages: runtimePackages.map((name) => ({
      ...allPackagesByName.get(name),
      dependencies: allPackagesByName.get(name).dependencies
        .filter((dependency) => reachable.has(dependency)),
    })),
    allPackages,
    allPackagesByName,
  };
}

function readPubPackageIdentity(packageRoot, component) {
  let pubspec;
  try {
    pubspec = fs.readFileSync(path.join(packageRoot, 'pubspec.yaml'), 'utf8');
  } catch {
    throw new Error(`Dart package root has no readable pubspec.yaml (${component.name})`);
  }
  const nameMatch = pubspec.match(/^name:\s*(['"]?)([A-Za-z0-9_-]+)\1\s*(?:#.*)?$/m);
  const versionMatch = pubspec.match(/^version:\s*(['"]?)([A-Za-z0-9.+-]+)\1\s*(?:#.*)?$/m);
  if (!nameMatch || (!versionMatch && !(component.source === 'sdk' && component.version === '0.0.0'))) {
    throw new Error(`Dart package root has invalid top-level name or version (${component.name})`);
  }
  const version = versionMatch?.[2] ?? null;
  if (version !== null && version !== component.version) {
    throw new Error(`Dart package configuration root and locked identity disagree (${component.name})`);
  }
  return {
    name: nameMatch[2],
    version,
    versionStatus: version === null
      ? 'sdk_version_governed_by_flutter_toolchain'
      : 'package_metadata_matches_lock',
  };
}

const flutterLicenseSeparator = `\n${'-'.repeat(80)}\n`;

function decodeUtf8(bytes, label) {
  try {
    return new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    throw new Error(`${label} is not valid UTF-8`);
  }
}

function parseYamlLicenseScalar(value, packageName) {
  const trimmed = value.trim();
  if (trimmed.startsWith('"')) {
    try {
      const parsed = JSON.parse(trimmed);
      if (typeof parsed === 'string' && parsed.length > 0) return parsed;
    } catch {
      // Reject YAML string syntaxes that this bounded reader does not support.
    }
  } else if (trimmed.startsWith("'")) {
    if (!trimmed.endsWith("'")) {
      throw new Error(`Flutter additional license path is unsupported (${packageName})`);
    }
    return trimmed.slice(1, -1).replace(/''/g, "'");
  } else {
    const scalar = trimmed.replace(/\s+#.*$/, '').trim();
    if (scalar.length > 0 && !/[\[\]{}&*!|>@`]/.test(scalar)) return scalar;
  }
  throw new Error(`Flutter additional license path is unsupported (${packageName})`);
}

export function parseFlutterAdditionalLicensePaths(pubspecText, packageName) {
  const lines = pubspecText.split(/\r?\n/);
  let inFlutter = false;
  let inLicenseList = false;
  let inlineList = null;
  const paths = [];
  for (const line of lines) {
    if (!inFlutter) {
      if (/^flutter:\s*(?:#.*)?$/.test(line)) inFlutter = true;
      continue;
    }
    if (line.length > 0 && !/^\s|^#/.test(line)) break;
    const licenseKey = line.match(/^  licenses:\s*(.*?)\s*(?:#.*)?$/);
    if (licenseKey) {
      if (inLicenseList || inlineList !== null) {
        throw new Error(`Flutter additional license list is duplicated (${packageName})`);
      }
      const value = licenseKey[1].trim();
      if (value.length === 0) {
        inLicenseList = true;
      } else if (value === '[]') {
        inlineList = [];
      } else if (value.startsWith('[') && value.endsWith(']')) {
        const body = value.slice(1, -1).trim();
        inlineList = body.length === 0
          ? []
          : body.split(/,(?=(?:[^'"]|'[^']*'|"[^"]*")*$)/)
            .map((entry) => parseYamlLicenseScalar(entry, packageName));
      } else {
        throw new Error(`Flutter additional license list is unsupported (${packageName})`);
      }
      continue;
    }
    if (!inLicenseList) continue;
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    const item = line.match(/^    -\s+(.+?)\s*(?:#.*)?$/);
    if (item) {
      paths.push(parseYamlLicenseScalar(item[1], packageName));
      continue;
    }
    if (/^  [A-Za-z_][A-Za-z0-9_-]*:\s*/.test(line)) {
      inLicenseList = false;
      continue;
    }
    if (/^    /.test(line)) {
      throw new Error(`Flutter additional license list is unsupported (${packageName})`);
    }
    inLicenseList = false;
  }
  return inlineList ?? paths;
}

function pathIsWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' ||
    (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function verifyFlutterLicenseCollectorSource(packageRoots, flutterToolchain, root) {
  if (
    !flutterToolchain ||
    typeof flutterToolchain.version !== 'string' ||
    !/^[0-9a-f]{40}$/.test(flutterToolchain.sourceRevision ?? '')
  ) {
    throw new Error('Pinned Flutter framework version and source revision are required');
  }
  const workflowPath = path.join(root, '.github/workflows/ci.yml');
  const workflowText = fs.readFileSync(workflowPath, 'utf8');
  const workflowVersion = workflowText.match(/^\s*flutter-version:\s*["']?([^\s"']+)/m)?.[1];
  if (workflowVersion !== flutterToolchain.version) {
    throw new Error('Flutter version in CI and open-source inventory disagree');
  }
  const flutterPackage = packageRoots.get('flutter');
  if (!flutterPackage) throw new Error('Dart package configuration has no Flutter SDK package');
  const sdkRoot = path.resolve(flutterPackage.rootPath, '..', '..');
  const relativeSources = [
    'packages/flutter_tools/lib/src/license_collector.dart',
    'packages/flutter_tools/lib/src/asset.dart',
    'packages/flutter_tools/lib/src/flutter_manifest.dart',
  ];
  let sourceCommit;
  try {
    sourceCommit = execFileSync('git', ['rev-parse', '--verify', 'HEAD'], {
      cwd: sdkRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch {
    throw new Error('Flutter SDK source revision cannot be verified');
  }
  if (sourceCommit !== flutterToolchain.sourceRevision) {
    throw new Error('Installed Flutter SDK revision does not match the pinned source revision');
  }
  const sourceFiles = relativeSources.map((relativePath) => {
    const currentPath = path.join(sdkRoot, relativePath);
    let currentBytes;
    let pinnedBytes;
    try {
      currentBytes = fs.readFileSync(currentPath);
      pinnedBytes = execFileSync('git', ['show', `${sourceCommit}:${relativePath}`], {
        cwd: sdkRoot,
        maxBuffer: 8 * 1024 * 1024,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch {
      throw new Error(`Pinned Flutter license collector source is missing (${relativePath})`);
    }
    if (!currentBytes.equals(pinnedBytes)) {
      throw new Error(`Flutter license collector source differs from its pinned commit (${relativePath})`);
    }
    return { path: relativePath, bytes: currentBytes.length, sha256: sha256(currentBytes) };
  });
  return {
    version: flutterToolchain.version,
    sourceRevision: sourceCommit,
    sourceFiles,
  };
}

export function reconstructFlutterLicenseBundle(root, runtimePubInventory, noticeBytes, flutterToolchain) {
  const packageConfigurationPath = path.join(root, '.dart_tool/package_config.json');
  let packageConfiguration;
  try {
    packageConfiguration = JSON.parse(fs.readFileSync(packageConfigurationPath, 'utf8'));
  } catch (error) {
    throw new Error(`Dart package configuration is not valid JSON: ${error.message}`);
  }
  if (!Array.isArray(packageConfiguration?.packages)) {
    throw new Error('Dart package configuration has no packages array');
  }

  const packageRoots = new Map();
  const configurationUrl = pathToFileURL(packageConfigurationPath);
  for (const entry of packageConfiguration.packages) {
    if (
      !entry ||
      typeof entry.name !== 'string' ||
      entry.name.length === 0 ||
      typeof entry.rootUri !== 'string' ||
      packageRoots.has(entry.name)
    ) {
      throw new Error('Dart package configuration has an invalid or duplicate package entry');
    }
    let packageUrl;
    try {
      packageUrl = new URL(entry.rootUri, configurationUrl);
    } catch {
      throw new Error(`Dart package configuration has an invalid root URI (${entry.name})`);
    }
    if (packageUrl.protocol !== 'file:') {
      throw new Error(`Dart package root is not a local file URI (${entry.name})`);
    }
    const rootPath = fileURLToPath(packageUrl);
    const rootUrl = pathToFileURL(`${rootPath}${path.sep}`);
    let packageUriRootUrl;
    try {
      packageUriRootUrl = new URL(entry.packageUri ?? 'lib/', rootUrl);
    } catch {
      throw new Error(`Dart package configuration has an invalid package URI (${entry.name})`);
    }
    if (packageUriRootUrl.protocol !== 'file:') {
      throw new Error(`Dart package URI is not a local file URI (${entry.name})`);
    }
    const packageUriRootPath = fileURLToPath(packageUriRootUrl);
    if (!pathIsWithin(rootPath, packageUriRootPath)) {
      throw new Error(`Dart package URI escapes its package root (${entry.name})`);
    }
    packageRoots.set(entry.name, { rootPath, packageUriRootPath });
  }
  const expectedComponents = new Map([
    [runtimePubInventory.root.name, {
      ...runtimePubInventory.root,
      source: 'project',
      lockDependency: 'root',
      sha256: null,
    }],
    ...runtimePubInventory.allPackages.map((component) => [component.name, component]),
  ]);
  if (
    packageRoots.size !== expectedComponents.size ||
    [...expectedComponents.keys()].some((name) => !packageRoots.has(name))
  ) {
    throw new Error('Dart package configuration and package graph identities disagree');
  }

  const licenseGroups = new Map();
  const additionalLicenseTexts = [];
  const packages = [];
  const runtimeNames = new Set(runtimePubInventory.packages.map((item) => item.name));
  for (const packageEntry of packageConfiguration.packages) {
    const component = expectedComponents.get(packageEntry.name);
    const packageRootEntry = packageRoots.get(packageEntry.name);
    const packageRoot = packageRootEntry.rootPath;
    if (!fs.existsSync(packageRoot) || !fs.statSync(packageRoot).isDirectory()) {
      throw new Error(`Dart package configuration root is missing (${component.name})`);
    }
    const packageIdentity = readPubPackageIdentity(packageRoot, component);
    if (packageIdentity.name !== component.name) {
      throw new Error(`Dart package configuration root and locked identity disagree (${component.name})`);
    }
    const pubspecBytes = fs.readFileSync(path.join(packageRoot, 'pubspec.yaml'));
    const pubspecText = decodeUtf8(pubspecBytes, `${component.name} pubspec.yaml`);
    const documents = [];
    const selectedMainPath = [
      path.resolve(packageRootEntry.packageUriRootPath, '../NOTICES'),
      path.resolve(packageRootEntry.packageUriRootPath, '../LICENSE'),
    ].find((candidate) => fs.existsSync(candidate));
    if (selectedMainPath && !pathIsWithin(packageRoot, selectedMainPath)) {
      throw new Error(`Flutter license input escapes its package root (${component.name})`);
    }
    if (selectedMainPath && !fs.statSync(selectedMainPath).isFile()) {
      throw new Error(`Flutter license input is not a regular file (${component.name})`);
    }
    if (selectedMainPath) {
      const bytes = fs.readFileSync(selectedMainPath);
      const sourceText = decodeUtf8(bytes, `${component.name} license input`);
      const rawLicenses = sourceText.split(flutterLicenseSeparator);
      const sections = [];
      for (const rawLicense of rawLicenses) {
        let packageNames = null;
        let licenseText = null;
        if (rawLicenses.length > 1) {
          const split = rawLicense.indexOf('\n\n');
          if (split >= 0) {
            packageNames = rawLicense.slice(0, split).split('\n');
            licenseText = rawLicense.slice(split + 2);
          }
        }
        if (licenseText === null) {
          packageNames = [component.name];
          licenseText = rawLicense;
        }
        const licenseTextSha256 = sha256(Buffer.from(licenseText, 'utf8'));
        let group = licenseGroups.get(licenseText);
        if (!group) {
          group = { packageNames: new Set() };
          licenseGroups.set(licenseText, group);
        }
        for (const name of packageNames) group.packageNames.add(name);
        sections.push({ packageNames, licenseTextSha256 });
      }
      documents.push({
        kind: path.basename(selectedMainPath).toUpperCase() === 'NOTICES'
          ? 'flutter_package_notices'
          : 'flutter_package_license',
        path: path.relative(packageRoot, selectedMainPath).split(path.sep).join('/'),
        bytes: bytes.length,
        sha256: sha256(bytes),
        sections,
      });
    }
    packages.push({
      name: component.name,
      version: component.version,
      source: component.source,
      lockDependency: component.lockDependency ?? 'unknown',
      expectedPackageArchiveSha256: component.sha256,
      packageVersionIdentityStatus: packageIdentity.versionStatus,
      packageRoot,
      pubspecText,
      dependencyClass: component.name === runtimePubInventory.root.name
        ? 'project_root'
        : runtimeNames.has(component.name)
          ? 'runtime'
          : 'development_only',
      documents,
    });
  }

  // Flutter's asset builder adds manifest-declared license files only for
  // transitive dependencies of the app (plus the app itself), and preserves
  // the insertion order produced by computeTransitiveDependencies. The
  // LicenseCollector still scans top-level LICENSE/NOTICES files from every
  // package in package_config.json, including dev-only packages.
  const rootName = runtimePubInventory.root.name;
  const packagesByName = new Map(packages.map((item) => [item.name, item]));
  const dependencyOrder = [rootName];
  const dependencySeen = new Set(dependencyOrder);
  const pending = [
    ...(runtimePubInventory.root.dependencies ?? []),
    ...(runtimePubInventory.root.devDependencies ?? []),
  ];
  while (pending.length > 0) {
    const name = pending.pop();
    if (dependencySeen.has(name)) continue;
    const dependency = packagesByName.get(name);
    if (!dependency) {
      throw new Error(`Flutter package graph references a missing resolved package (${name})`);
    }
    dependencySeen.add(name);
    dependencyOrder.push(name);
    const packageGraphEntry = runtimePubInventory.allPackagesByName.get(name);
    pending.push(...(packageGraphEntry?.dependencies ?? []));
  }

  for (const name of dependencyOrder) {
    if (name !== rootName && !runtimeNames.has(name)) continue;
    const packageRecord = packagesByName.get(name);
    if (!packageRecord) throw new Error(`Flutter package graph references a missing package (${name})`);
    for (const relativeLicensePath of parseFlutterAdditionalLicensePaths(packageRecord.pubspecText, name)) {
      if (path.isAbsolute(relativeLicensePath)) {
        throw new Error(`Flutter additional license path must be package-relative (${name})`);
      }
      const licensePath = path.resolve(packageRecord.packageRoot, relativeLicensePath);
      if (!pathIsWithin(packageRecord.packageRoot, licensePath)) {
        throw new Error(`Flutter additional license path escapes its package root (${name})`);
      }
      if (!fs.existsSync(licensePath) || !fs.statSync(licensePath).isFile()) {
        throw new Error(`Flutter additional license input is missing (${name})`);
      }
      const bytes = fs.readFileSync(licensePath);
      const text = decodeUtf8(bytes, `${name} additional license input`);
      additionalLicenseTexts.push(text);
      packageRecord.documents.push({
        kind: 'flutter_manifest_additional_license',
        path: path.relative(packageRecord.packageRoot, licensePath).split(path.sep).join('/'),
        bytes: bytes.length,
        sha256: sha256(bytes),
        sections: [{
          packageNames: [name],
          licenseTextSha256: sha256(Buffer.from(text, 'utf8')),
        }],
      });
    }
  }
  for (const packageRecord of packages) {
    delete packageRecord.packageRoot;
    delete packageRecord.pubspecText;
    packageRecord.status = packageRecord.documents.length === 0
      ? 'no_license_input_selected_by_flutter'
      : 'selected_by_pinned_flutter_license_collector';
  }

  const licenseSections = [...licenseGroups.entries()]
    .map(([licenseText, group]) => `${[...group.packageNames].sort().join('\n')}\n\n${licenseText}`)
    .sort((left, right) => left < right ? -1 : left > right ? 1 : 0);
  const expectedNoticeBytes = Buffer.from(
    [...licenseSections, ...additionalLicenseTexts].join(flutterLicenseSeparator),
    'utf8',
  );
  const sourceCode = verifyFlutterLicenseCollectorSource(packageRoots, flutterToolchain, root);
  const runtimePackages = packages.filter((item) => item.dependencyClass === 'runtime');
  const exactMatch = expectedNoticeBytes.equals(noticeBytes);
  return {
    method: 'pinned_flutter_license_collector_reconstruction_v1',
    scope: 'Reconstructs the pinned Flutter LicenseCollector selection, 80-hyphen section parsing, de-duplication, package-name grouping, and manifest-declared additional-license order. Exact byte equality verifies this NOTICE bundle against the recorded local inputs and collector source; it does not validate extracted cache bytes against hosted archive hashes or establish SPDX/legal completeness.',
    status: exactMatch ? 'verified_exact_reconstruction' : 'mismatch',
    noticeSha256: sha256(noticeBytes),
    expectedNoticeSha256: sha256(expectedNoticeBytes),
    noticeBytes: noticeBytes.length,
    expectedNoticeBytes: expectedNoticeBytes.length,
    exactNoticeReconstructionMatch: exactMatch,
    packageConfigurationPath: '.dart_tool/package_config.json',
    packageConfigurationSha256: sha256(fs.readFileSync(packageConfigurationPath)),
    flutterLicenseCollectorSource: sourceCode,
    packageCount: packages.length,
    runtimePackageCount: runtimePackages.length,
    developmentOnlyPackageCount: packages.filter((item) => item.dependencyClass === 'development_only').length,
    runtimePackageCountWithCollectedLicenseInputs: runtimePackages.filter((item) => item.documents.length > 0).length,
    selectedLicenseDocumentCount: packages.reduce((count, item) => count + item.documents.length, 0),
    packagesWithoutSelectedLicenseInput: packages.filter((item) => item.documents.length === 0).map((item) => item.name),
    packages,
  };
}

function gradleComponentKey(identity) {
  if (identity?.kind === 'maven') {
    return `maven:${identity.group}:${identity.name}:${identity.version}`;
  }
  if (identity?.kind === 'pub') return `pub:${identity.name}`;
  throw new Error('Android Gradle dependency graph contains an unsupported component identity');
}

function parseAndroidGradleGraph(graphBytes, pubInventory, androidPluginNames) {
  let graph;
  try {
    graph = JSON.parse(graphBytes.toString('utf8'));
  } catch (error) {
    throw new Error(`Android Gradle dependency graph is not valid JSON: ${error.message}`);
  }
  if (
      graph?.schemaUri !== ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_URI ||
      graph?.schemaVersion !== ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_VERSION ||
    graph.configuration !== 'debugRuntimeClasspath' ||
    !graph.root ||
    !Array.isArray(graph.root.dependencies) ||
    !Array.isArray(graph.components) ||
    graph.components.length === 0
  ) {
    throw new Error('Android Gradle dependency graph has an unsupported schema or configuration');
  }

  const componentsByKey = new Map();
  for (const component of graph.components) {
    const identity = component?.id;
    if (
      !identity ||
      !Array.isArray(component.dependencies) ||
      !Array.isArray(component.artifacts) ||
      (identity.kind === 'maven' &&
        (![identity.group, identity.name, identity.version].every((value) =>
          typeof value === 'string' && value.length > 0))) ||
      (identity.kind === 'pub' &&
        (typeof identity.name !== 'string' || identity.name.length === 0)) ||
      !['maven', 'pub'].includes(identity.kind)
    ) {
      throw new Error('Android Gradle dependency graph contains an invalid component');
    }
    const key = gradleComponentKey(identity);
    if (componentsByKey.has(key)) {
      throw new Error(`Android Gradle dependency graph contains duplicate component ${key}`);
    }
    if (identity.kind === 'pub' && !pubInventory.allPackagesByName.has(identity.name)) {
      throw new Error(`Android Gradle project dependency is not present in the Pub package graph: ${identity.name}`);
    }
    if (identity.kind === 'pub' && !androidPluginNames.has(identity.name)) {
      throw new Error(`Android Gradle project dependency is not listed as an Android Flutter plugin: ${identity.name}`);
    }
    const artifacts = component.artifacts.map((artifact) => {
      if (
        !artifact ||
        typeof artifact.fileName !== 'string' ||
        artifact.fileName.length === 0 ||
        path.basename(artifact.fileName) !== artifact.fileName ||
        !Number.isSafeInteger(artifact.bytes) ||
        artifact.bytes < 0 ||
        !/^[a-f0-9]{64}$/i.test(artifact.sha256 ?? '') ||
        !Array.isArray(artifact.licenseDocuments)
      ) {
        throw new Error(`Android Gradle dependency graph has invalid artifact evidence for ${key}`);
      }
      const licenseDocuments = artifact.licenseDocuments.map((document) => {
        if (
          !document ||
          typeof document.archivePath !== 'string' ||
          document.archivePath.length === 0 ||
          document.archivePath.startsWith('/') ||
          document.archivePath.includes('\\') ||
          path.posix.normalize(document.archivePath) === '.' ||
          path.posix.normalize(document.archivePath) === '..' ||
          path.posix.normalize(document.archivePath).startsWith('../') ||
          !Number.isSafeInteger(document.bytes) ||
          document.bytes <= 0 ||
          !/^[a-f0-9]{64}$/i.test(document.sha256 ?? '')
        ) {
          throw new Error(`Android Gradle dependency graph has invalid embedded license evidence for ${key}`);
        }
        return {
          archivePath: document.archivePath,
          bytes: document.bytes,
          sha256: document.sha256.toLowerCase(),
        };
      }).sort((left, right) => left.archivePath.localeCompare(right.archivePath));
      return {
        fileName: artifact.fileName,
        bytes: artifact.bytes,
        sha256: artifact.sha256.toLowerCase(),
        licenseDocuments,
      };
    }).sort((left, right) =>
      `${left.fileName}:${left.sha256}`.localeCompare(`${right.fileName}:${right.sha256}`),
    );
    componentsByKey.set(key, { identity, key, artifacts, dependencies: component.dependencies });
  }

  const normalizeEdges = (edges, owner) => {
    const targets = new Set();
    for (const identity of edges) {
      const target = gradleComponentKey(identity);
      if (!componentsByKey.has(target)) {
        throw new Error(`Android Gradle dependency graph has a dangling edge from ${owner} to ${target}`);
      }
      targets.add(target);
    }
    return [...targets].sort((left, right) => left.localeCompare(right));
  };
  const rootDependencies = normalizeEdges(graph.root.dependencies, 'application root');
  for (const component of componentsByKey.values()) {
    component.dependencies = normalizeEdges(component.dependencies, component.key);
  }

  const reachable = new Set();
  const pending = [...rootDependencies];
  while (pending.length > 0) {
    const key = pending.pop();
    if (reachable.has(key)) continue;
    reachable.add(key);
    pending.push(...componentsByKey.get(key).dependencies);
  }
  if (reachable.size !== componentsByKey.size) {
    const orphans = [...componentsByKey.keys()].filter((key) => !reachable.has(key));
    throw new Error(`Android Gradle dependency graph contains unreachable components: ${orphans.join(', ')}`);
  }

  return {
    configuration: graph.configuration,
    rootDependencies,
    components: [...componentsByKey.values()].sort((left, right) =>
      left.key.localeCompare(right.key),
    ),
    componentCount: componentsByKey.size,
    mavenComponentCount: [...componentsByKey.values()].filter((item) => item.identity.kind === 'maven').length,
    pubProjectComponentCount: [...componentsByKey.values()].filter((item) => item.identity.kind === 'pub').length,
    artifactCount: [...componentsByKey.values()].reduce((total, item) => total + item.artifacts.length, 0),
    mavenArtifactsWithLicenseDocuments: [...componentsByKey.values()]
      .filter((item) => item.identity.kind === 'maven')
      .flatMap((item) => item.artifacts)
      .filter((artifact) => artifact.licenseDocuments.length > 0).length,
    embeddedLicenseDocumentCount: [...componentsByKey.values()]
      .filter((item) => item.identity.kind === 'maven')
      .flatMap((item) => item.artifacts)
      .reduce((count, artifact) => count + artifact.licenseDocuments.length, 0),
    rootDependencyCount: rootDependencies.length,
  };
}

function pubComponentRef(component) {
  return `urn:parkinsum:pub:${encodeURIComponent(component.name)}@${encodeURIComponent(component.version)}:${component.source}`;
}

function pubCycloneDxComponent(component, licenseTextEvidence = null) {
  const packageLicenseFiles = licenseTextEvidence?.documents ?? [];
  return {
    type: 'library',
    name: component.name,
    version: component.version,
    'bom-ref': pubComponentRef(component),
    scope: 'required',
    ...(component.sha256
      ? { hashes: [{ alg: 'SHA-256', content: component.sha256 }] }
      : {}),
    properties: [
      { name: 'parkinsum:packageManager', value: 'Dart Pub' },
      { name: 'parkinsum:packageSource', value: component.source },
      { name: 'parkinsum:pubLockClassification', value: component.lockDependency ?? 'unknown' },
      { name: 'parkinsum:licenseAssertionStatus', value: 'NOASSERTION' },
      {
        name: 'parkinsum:flutterLicenseCollectorInputStatus',
        value: licenseTextEvidence?.status ?? 'not_observed',
      },
      {
        name: 'parkinsum:flutterLicenseCollectorSourceDocuments',
        value: JSON.stringify(packageLicenseFiles.map(({ kind, path: filePath, bytes, sha256: digest, sections }) => ({
          kind,
          path: filePath,
          bytes,
          sha256: digest,
          sections,
        }))),
      },
    ],
  };
}

function mavenComponentRef(identity) {
  return `urn:parkinsum:gradle:maven:${encodeURIComponent(identity.group)}:${encodeURIComponent(identity.name)}@${encodeURIComponent(identity.version)}`;
}

function mavenPurl(identity) {
  return `pkg:maven/${encodeURIComponent(identity.group)}/${encodeURIComponent(identity.name)}@${encodeURIComponent(identity.version)}`;
}

function buildCycloneDxBom({
  platform,
  artifact,
  pubInventory,
  pubLockSha256,
  pubPackageConfigurationSha256,
  pubFlutterLicenseCollectorEvidence,
  androidGradleGraph = null,
  androidGradleGraphSha256 = null,
  flutterPluginMetadataSha256 = null,
}) {
  const rootRef = `urn:parkinsum:artifact:${platform}:${artifact.sha256}`;
  if ((platform === 'android') !== Boolean(androidGradleGraph)) {
    throw new Error('Android CycloneDX output requires its resolved Gradle dependency graph');
  }

  const pubComponentsByName = new Map(pubInventory.packages.map((component) => [
    component.name,
    { ...component },
  ]));
  const pubLicenseEvidenceByName = new Map(
    pubFlutterLicenseCollectorEvidence.packages.map((component) => [component.name, component]),
  );
  if (androidGradleGraph) {
    for (const node of androidGradleGraph.components) {
      if (node.identity.kind !== 'pub') continue;
      const packageRecord = pubInventory.allPackagesByName.get(node.identity.name);
      if (!packageRecord || !['hosted', 'sdk'].includes(packageRecord.source)) {
        throw new Error(`CycloneDX cannot identify Android Pub project source ${packageRecord?.source ?? 'unknown'} (${node.identity.name})`);
      }
      pubComponentsByName.set(node.identity.name, {
        ...packageRecord,
        dependencies: pubInventory.packages.find((item) => item.name === node.identity.name)?.dependencies ?? [],
      });
    }
  }

  const refs = new Map([...pubComponentsByName.values()].map((component) => [
    component.name,
    pubComponentRef(component),
  ]));
  const componentsByRef = new Map([...pubComponentsByName.values()].map((component) => [
    refs.get(component.name),
    pubCycloneDxComponent(component, pubLicenseEvidenceByName.get(component.name)),
  ]));
  const dependencyEdges = new Map([[rootRef, new Set()]]);
  for (const component of pubComponentsByName.values()) {
    dependencyEdges.set(refs.get(component.name), new Set());
  }

  for (const name of pubInventory.root.dependencies) {
    if (refs.has(name)) dependencyEdges.get(rootRef).add(refs.get(name));
  }
  for (const component of pubInventory.packages) {
    const componentRef = refs.get(component.name);
    for (const dependency of component.dependencies) {
      if (refs.has(dependency)) dependencyEdges.get(componentRef).add(refs.get(dependency));
    }
  }

  if (androidGradleGraph) {
    const gradleRefs = new Map();
    for (const node of androidGradleGraph.components) {
      const ref = node.identity.kind === 'pub'
        ? refs.get(node.identity.name)
        : mavenComponentRef(node.identity);
      gradleRefs.set(node.key, ref);
      if (node.identity.kind === 'maven') {
        if (componentsByRef.has(ref)) {
          throw new Error(`Android Gradle component reference collides with another component: ${ref}`);
        }
        componentsByRef.set(ref, {
          type: 'library',
          group: node.identity.group,
          name: node.identity.name,
          version: node.identity.version,
          purl: mavenPurl(node.identity),
          'bom-ref': ref,
          scope: 'required',
          ...(node.artifacts.length === 1
            ? { hashes: [{ alg: 'SHA-256', content: node.artifacts[0].sha256 }] }
            : {}),
          properties: [
            { name: 'parkinsum:packageManager', value: 'Gradle/Maven' },
            { name: 'parkinsum:dependencyConfiguration', value: androidGradleGraph.configuration },
            { name: 'parkinsum:licenseAssertionStatus', value: 'NOASSERTION' },
            { name: 'parkinsum:resolvedArtifactEvidence', value: JSON.stringify(node.artifacts) },
            {
              name: 'parkinsum:embeddedLicenseDocumentEvidence',
              value: JSON.stringify(node.artifacts.flatMap((artifact) =>
                artifact.licenseDocuments.map((document) => ({
                  artifactFileName: artifact.fileName,
                  artifactSha256: artifact.sha256,
                  ...document,
                })),
              )),
            },
          ],
        });
        dependencyEdges.set(ref, new Set());
      } else {
        const component = componentsByRef.get(ref);
        component.properties.push(
          { name: 'parkinsum:androidGradleProject', value: 'true' },
          { name: 'parkinsum:resolvedAndroidArtifactEvidence', value: JSON.stringify(node.artifacts) },
        );
      }
    }

    for (const targetKey of androidGradleGraph.rootDependencies) {
      dependencyEdges.get(rootRef).add(gradleRefs.get(targetKey));
    }
    for (const node of androidGradleGraph.components) {
      const sourceRef = gradleRefs.get(node.key);
      for (const targetKey of node.dependencies) {
        dependencyEdges.get(sourceRef).add(gradleRefs.get(targetKey));
      }
    }
  }

  const components = [...componentsByRef.values()].sort((left, right) =>
    left['bom-ref'].localeCompare(right['bom-ref']),
  );
  const dependencyRecords = [...dependencyEdges.entries()].map(([ref, targets]) => ({
    ref,
    dependsOn: [...targets].sort((left, right) => left.localeCompare(right)),
  })).sort((left, right) => left.ref.localeCompare(right.ref));
  const allRefs = [rootRef, ...components.map((component) => component['bom-ref'])]
    .sort((left, right) => left.localeCompare(right));
  const graphScope = androidGradleGraph
    ? 'Dart Pub packages reachable from root dependencies plus the resolved Android :app debugRuntimeClasspath graph; target-binary inclusion is not asserted'
    : 'Dart Pub dependencies reachable from the root dependencies array; target-binary inclusion is not asserted';
  const bom = {
    bomFormat: 'CycloneDX',
    specVersion: '1.7',
    serialNumber: `urn:uuid:${randomUUID()}`,
    version: 1,
    metadata: {
      component: {
        type: 'application',
        name: `ParkinSUM ${platform} build`,
        version: pubInventory.root.version,
        'bom-ref': rootRef,
        hashes: [{ alg: 'SHA-256', content: artifact.sha256 }],
        properties: [
          {
            name: 'parkinsum:artifactDigestScope',
            value: artifact.kind === 'flutter_web_build_tree'
              ? 'SHA-256 over sorted Web output file hashes and relative paths'
              : 'SHA-256 over the complete Android APK bytes',
          },
          { name: 'parkinsum:pubspecLockSha256', value: pubLockSha256 },
          { name: 'parkinsum:pubPackageConfigurationSha256', value: pubPackageConfigurationSha256 },
          {
            name: 'parkinsum:pubFlutterLicenseCollectorEvidenceStatus',
            value: pubFlutterLicenseCollectorEvidence.status,
          },
          { name: 'parkinsum:dependencyGraphScope', value: graphScope },
          ...(androidGradleGraphSha256
            ? [{ name: 'parkinsum:androidGradleDependencyGraphSha256', value: androidGradleGraphSha256 }]
            : []),
          ...(flutterPluginMetadataSha256
            ? [{ name: 'parkinsum:flutterPluginMetadataSha256', value: flutterPluginMetadataSha256 }]
            : []),
        ],
      },
    },
    components,
    dependencies: dependencyRecords,
    compositions: [{ aggregate: 'incomplete', assemblies: allRefs }],
  };
  const contentDigest = sha256(Buffer.from(JSON.stringify({
    metadata: bom.metadata,
    components: bom.components,
    dependencies: bom.dependencies,
    compositions: bom.compositions,
  }), 'utf8'));
  return {
    bom,
    contentDigest,
    componentCount: components.length,
    pubComponentCount: pubComponentsByName.size,
    androidGradleComponentCount: androidGradleGraph?.componentCount ?? 0,
  };
}

export function buildOpenSourceReleaseEvidence({
  root = REPOSITORY_ROOT,
  webDirectory = path.join(root, 'build/web'),
  androidApkPath = path.join(root, DEFAULT_ANDROID_APK),
  androidGradleGraphPath = path.join(root, DEFAULT_ANDROID_GRADLE_GRAPH),
  webOnly = false,
  readArchiveEntry = readZipEntry,
}) {
  const web = describeWebBuild(webDirectory);
  const platforms = { web: web.artifact };
  const noticeBundles = { web: web.flutterGeneratedNotice };
  let android = null;
  let noticesMatch = null;

  if (!webOnly) {
    android = describeAndroidApk(androidApkPath, readArchiveEntry);
    platforms.android = android.artifact;
    noticeBundles.android = android.flutterGeneratedNotice;
    noticesMatch =
      web.flutterGeneratedNotice.sha256 ===
      android.flutterGeneratedNotice.decompressed.sha256;
    if (!noticesMatch) {
      throw new Error('Flutter-generated Web and Android NOTICE contents differ');
    }
  }

  const provenance = readSourceAndInventory(root);
  const pubFlutterLicenseCollectorEvidence = reconstructFlutterLicenseBundle(
    root,
    provenance.packageGraph.runtimePubInventory,
    web.noticeBytes,
    provenance.flutterToolchain,
  );
  if (
    pubFlutterLicenseCollectorEvidence.packageConfigurationSha256 !==
    provenance.packageConfiguration.sha256
  ) {
    throw new Error('Dart package configuration changed while release evidence was collected');
  }
  if (pubFlutterLicenseCollectorEvidence.status !== 'verified_exact_reconstruction') {
    throw new Error(
      `Flutter NOTICE does not match pinned license-collector inputs ` +
        `(expected ${pubFlutterLicenseCollectorEvidence.expectedNoticeSha256}, actual ${pubFlutterLicenseCollectorEvidence.noticeSha256})`,
    );
  }
  let androidGradleGraph = null;
  let androidGradleGraphEvidence = null;
  let flutterPluginMetadataSha256 = null;
  if (android) {
    let graphBytes;
    try {
      graphBytes = fs.readFileSync(androidGradleGraphPath);
    } catch {
      throw new Error(`Android Gradle dependency graph is missing: ${path.relative(root, androidGradleGraphPath)}`);
    }
    const pluginMetadataPath = path.join(root, '.flutter-plugins-dependencies');
    const pluginMetadataBytes = fs.readFileSync(pluginMetadataPath);
    let pluginMetadata;
    try {
      pluginMetadata = JSON.parse(pluginMetadataBytes.toString('utf8'));
    } catch (error) {
      throw new Error(`Flutter plugin metadata is not valid JSON: ${error.message}`);
    }
    const androidPlugins = pluginMetadata?.plugins?.android;
    if (!Array.isArray(androidPlugins) || androidPlugins.some((plugin) =>
      typeof plugin?.name !== 'string' || plugin.name.length === 0,
    )) {
      throw new Error('Flutter plugin metadata has no valid Android plugin list');
    }
    const androidPluginNames = new Set(androidPlugins.map((plugin) => plugin.name));
    if (androidPluginNames.size !== androidPlugins.length) {
      throw new Error('Flutter plugin metadata contains duplicate Android plugin names');
    }
    androidGradleGraph = parseAndroidGradleGraph(
      graphBytes,
      provenance.packageGraph.runtimePubInventory,
      androidPluginNames,
    );
    flutterPluginMetadataSha256 = sha256(pluginMetadataBytes);
    androidGradleGraphEvidence = {
      path: path.relative(root, androidGradleGraphPath).split(path.sep).join('/'),
      schemaUri: ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_URI,
      schemaVersion: ANDROID_GRADLE_RUNTIME_GRAPH_SCHEMA_VERSION,
      configuration: androidGradleGraph.configuration,
      sha256: sha256(graphBytes),
      componentCount: androidGradleGraph.componentCount,
      mavenComponentCount: androidGradleGraph.mavenComponentCount,
      pubProjectComponentCount: androidGradleGraph.pubProjectComponentCount,
      artifactCount: androidGradleGraph.artifactCount,
      mavenArtifactsWithLicenseDocuments: androidGradleGraph.mavenArtifactsWithLicenseDocuments,
      embeddedLicenseDocumentCount: androidGradleGraph.embeddedLicenseDocumentCount,
      rootDependencyCount: androidGradleGraph.rootDependencyCount,
      flutterPluginMetadataPath: path.relative(root, pluginMetadataPath).split(path.sep).join('/'),
      flutterPluginMetadataSha256,
    };
  }
  const artifacts = { web: web.artifact, ...(android ? { android: android.artifact } : {}) };
  const sbomDocuments = {};
  for (const [platform, artifact] of Object.entries(artifacts)) {
    sbomDocuments[platform] = buildCycloneDxBom({
      platform,
      artifact,
      pubInventory: provenance.packageGraph.runtimePubInventory,
      pubLockSha256: provenance.dependencyLocks.find((item) => item.path === 'pubspec.lock').sha256,
      pubPackageConfigurationSha256: provenance.packageConfiguration.sha256,
      pubFlutterLicenseCollectorEvidence,
      androidGradleGraph: platform === 'android' ? androidGradleGraph : null,
      androidGradleGraphSha256: platform === 'android' ? androidGradleGraphEvidence.sha256 : null,
      flutterPluginMetadataSha256: platform === 'android' ? flutterPluginMetadataSha256 : null,
    });
  }
  const statement = {
    schemaUri: OPEN_SOURCE_RELEASE_EVIDENCE_SCHEMA_URI,
    schemaVersion: OPEN_SOURCE_RELEASE_EVIDENCE_SCHEMA_VERSION,
    evidenceKind: 'open_source_release_notice_attestation',
    status: 'passed',
    generatedAt: null,
    source: provenance.source,
    inventory: provenance.inventory,
    schemaContract: provenance.schemaContract,
    androidGradleGraphSchemaContract: provenance.androidGraphSchemaContract,
    dependencyLocks: provenance.dependencyLocks,
    pubPackageConfiguration: provenance.packageConfiguration,
    pubFlutterLicenseCollectorEvidence,
    platforms,
    flutterGeneratedNoticeBundles: noticeBundles,
    crossPlatformFlutterNoticeContentsMatch: noticesMatch,
    androidPlatformNotice: android?.platformNotice ?? null,
    signature: { status: 'unsigned', signer: null },
    sbom: {
      status: 'partial',
      format: 'CycloneDX',
      specVersion: '1.7',
      compositionAggregate: 'incomplete',
      pubDependencyComponentCount: provenance.packageGraph.runtimePubInventory.packages.length,
      packageGraphPath: provenance.packageGraph.path,
      packageGraphSha256: provenance.packageGraph.sha256,
      ...(androidGradleGraphEvidence
        ? { androidGradleDependencyGraph: androidGradleGraphEvidence }
        : {}),
      scope: 'Web documents bind the artifact to Pub dependencies reachable from root dependencies and verify the generated Flutter NOTICE bytes against license inputs reconstructed from the pinned Flutter SDK collector. Android documents also bind the resolved debugRuntimeClasspath Gradle graph, with Flutter plugin projects mapped to Pub packages; target-binary inclusion is not asserted.',
      excluded: [
        'Gradle buildscript/plugin classpath, Android SDK/NDK, and dependencies outside :app debugRuntimeClasspath',
        'Dart dev-only dependencies not reachable from Pub runtime dependencies or the resolved Android Gradle graph',
        'Development-only Google CQL Go and CQF CQL JVM Gradle/Maven tooling, plus Node build/release tooling',
        'target-specific filtering of platform implementation packages from the resolved Pub graph',
        'Android Maven license text materials, non-Pub source license materials, and source-offer evidence',
        'all release platforms and distribution channels',
      ],
      documents: Object.fromEntries(Object.entries(sbomDocuments).map(([platform, document]) => [
        platform,
        {
          serialNumber: document.bom.serialNumber,
          contentDigest: document.contentDigest,
          componentCount: document.componentCount,
          pubComponentCount: document.pubComponentCount,
          androidGradleComponentCount: document.androidGradleComponentCount,
          artifactSha256: artifacts[platform].sha256,
        },
      ])),
    },
    boundary:
      'Release hygiene evidence only. NOTICE presence and equality do not prove license completeness, legal compatibility, source-offer fulfillment, scientific validity, clinical effectiveness, or regulatory clearance.',
  };
  statement.statementId = sha256(Buffer.from(JSON.stringify(statement), 'utf8'));
  Object.defineProperty(statement, 'cycloneDxDocuments', {
    value: Object.fromEntries(Object.entries(sbomDocuments).map(([platform, document]) => [
      platform,
      document.bom,
    ])),
    enumerable: false,
  });
  return statement;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) throw new Error(`Unexpected argument: ${token}`);
    const key = token.slice(2);
    const value = argv[index + 1];
    if (value == null || value.startsWith('--')) parsed[key] = true;
    else {
      parsed[key] = value;
      index += 1;
    }
  }
  return parsed;
}

async function main() {
  try {
    const args = parseArgs(process.argv.slice(2));
    const root = path.resolve(args.root ?? REPOSITORY_ROOT);
    const evidence = buildOpenSourceReleaseEvidence({
      root,
      webDirectory: path.resolve(root, args['web-dir'] ?? 'build/web'),
      androidApkPath: path.resolve(
        root,
        args['android-apk'] ?? DEFAULT_ANDROID_APK,
      ),
      androidGradleGraphPath: path.resolve(
        root,
        args['android-gradle-graph'] ?? DEFAULT_ANDROID_GRADLE_GRAPH,
      ),
      webOnly: args['web-only'] === true,
    });
    const output = args.output
      ? path.resolve(root, args.output)
      : path.join(root, 'build/open_source_release_evidence/latest.json');
    fs.mkdirSync(path.dirname(output), { recursive: true });
    for (const [platform, bom] of Object.entries(evidence.cycloneDxDocuments)) {
      const basename = path.basename(output).replace(/\.json$/i, '');
      const sbomPath = path.join(path.dirname(output), `${basename}.${platform}.cdx.json`);
      const sbomBytes = Buffer.from(`${JSON.stringify(bom, null, 2)}\n`, 'utf8');
      fs.writeFileSync(sbomPath, sbomBytes);
      evidence.sbom.documents[platform] = {
        ...evidence.sbom.documents[platform],
        path: path.relative(root, sbomPath).split(path.sep).join('/'),
        sha256: sha256(sbomBytes),
      };
    }
    evidence.statementId = sha256(Buffer.from(JSON.stringify({
      ...evidence,
      statementId: undefined,
    }), 'utf8'));
    fs.writeFileSync(output, `${JSON.stringify(evidence, null, 2)}\n`);
    process.stdout.write(
      `Open-source release evidence passed (${Object.keys(evidence.platforms).join(', ')}); ` +
        `unsigned and ${evidence.sbom.specVersion} SBOM ${evidence.sbom.status}/` +
        `${evidence.sbom.compositionAggregate}: ${path.relative(root, output)}\n`,
    );
  } catch (error) {
    process.stderr.write(`Open-source release evidence failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
