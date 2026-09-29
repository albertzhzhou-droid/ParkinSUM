#!/usr/bin/env node
// Source-level inventory for platform network controls. This deliberately
// reports repository configuration only; merged manifests, hosted response
// headers, and release runtime behavior require separate artifact evidence.

import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function readText(projectRoot, relativePath) {
  const absolutePath = path.join(projectRoot, relativePath);
  return existsSync(absolutePath) ? readFileSync(absolutePath, 'utf8') : null;
}

function stripXmlComments(value) {
  return value.replace(/<!--[\s\S]*?-->/g, '');
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function xmlAttribute(tag, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return tag.match(new RegExp(`(?:^|\\s)${escaped}\\s*=\\s*"([^"]*)"`))?.[1] ?? null;
}

function listFiles(directory, predicate) {
  if (!existsSync(directory)) return [];
  const result = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...listFiles(absolutePath, predicate));
    else if (entry.isFile() && predicate(entry.name)) result.push(absolutePath);
  }
  return result;
}

function sourceManifest(projectRoot, absolutePath) {
  const relativePath = path.relative(projectRoot, absolutePath).split(path.sep).join('/');
  const xml = stripXmlComments(readFileSync(absolutePath, 'utf8'));
  const applicationTag = xml.match(/<application\b[^>]*>/)?.[0] ?? '';
  const permissions = [...xml.matchAll(/<uses-permission(?:-[A-Za-z0-9_-]+)?\b[^>]*>/g)]
    .map((match) => xmlAttribute(match[0], 'android:name'));
  return {
    path: relativePath,
    internetPermission: permissions.includes('android.permission.INTERNET'),
    usesCleartextTraffic: xmlAttribute(applicationTag, 'android:usesCleartextTraffic'),
    networkSecurityConfig: xmlAttribute(applicationTag, 'android:networkSecurityConfig'),
  };
}

function hasPlistKey(xml, key) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`<key>\\s*${escaped}\\s*</key>`).test(stripXmlComments(xml));
}

function plistDictionarySource(xml, key) {
  const cleanXml = stripXmlComments(xml);
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const keyMatch = new RegExp(`<key>\\s*${escaped}\\s*</key>`).exec(cleanXml);
  if (!keyMatch) return null;
  const afterKey = cleanXml.slice(keyMatch.index + keyMatch[0].length);
  const opening = /<dict\s*\/?>/.exec(afterKey);
  if (!opening) return null;
  const start = keyMatch.index + keyMatch[0].length + opening.index;
  if (/\/>$/.test(opening[0])) return opening[0];
  const tokens = /<\/?dict\b[^>]*>/g;
  tokens.lastIndex = start;
  let depth = 0;
  for (let match = tokens.exec(cleanXml); match; match = tokens.exec(cleanXml)) {
    if (/^<dict\b/i.test(match[0])) depth += 1;
    else depth -= 1;
    if (depth === 0) return cleanXml.slice(start, tokens.lastIndex);
  }
  return cleanXml.slice(start);
}

function plistNetworkFacts(projectRoot, platform, projectPath, deploymentKey) {
  const infoPlistPath = `${platform}/Runner/Info.plist`;
  const plist = readText(projectRoot, infoPlistPath);
  const project = readText(projectRoot, projectPath) ?? '';
  const deploymentTargets = [...new Set(
    [...project.matchAll(new RegExp(`${deploymentKey}\\s*=\\s*([^;]+);`, 'g'))]
      .map((match) => match[1].trim()),
  )].sort();
  const networkKeys = [
    'NSAppTransportSecurity',
    'NSAllowsArbitraryLoads',
    'NSAllowsArbitraryLoadsForMedia',
    'NSAllowsArbitraryLoadsInWebContent',
    'NSAllowsLocalNetworking',
    'NSExceptionDomains',
    'NSLocalNetworkUsageDescription',
  ];
  const escapedKeys = networkKeys.join('|');
  const settingFiles = [
    projectPath,
    ...listFiles(path.join(projectRoot, platform), (name) => name.endsWith('.xcconfig'))
      .map((absolutePath) => path.relative(projectRoot, absolutePath).split(path.sep).join('/')),
  ];
  const projectNetworkOverrides = settingFiles.flatMap((relativePath) => {
    const text = readText(projectRoot, relativePath);
    if (text === null) return [];
    const cleanText = text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\r\n]*/g, '');
    return [...cleanText.matchAll(new RegExp(
      `INFOPLIST_KEY_(${escapedKeys})\\s*=\\s*([^;]+);`,
      'g',
    ))].map((match) => ({ path: relativePath, key: match[1], value: match[2].trim() }));
  }).sort((left, right) =>
    `${left.path}:${left.key}`.localeCompare(`${right.path}:${right.key}`),
  );
  const atsDictionary = plist === null ? null : plistDictionarySource(plist, 'NSAppTransportSecurity');
  return {
    infoPlistPath,
    infoPlistPresent: plist !== null,
    atsDictionaryPresent: plist === null ? null : atsDictionary !== null,
    atsDictionarySha256: atsDictionary === null ? null : sha256(atsDictionary),
    allowsArbitraryLoadsPresent: plist === null ? null : hasPlistKey(plist, 'NSAllowsArbitraryLoads'),
    allowsLocalNetworkingPresent: plist === null ? null : hasPlistKey(plist, 'NSAllowsLocalNetworking'),
    exceptionDomainsPresent: plist === null ? null : hasPlistKey(plist, 'NSExceptionDomains'),
    localNetworkUsageDescriptionPresent:
      plist === null ? null : hasPlistKey(plist, 'NSLocalNetworkUsageDescription'),
    projectNetworkOverrides,
    deploymentTargets,
  };
}

function parseCspConnectSources(value) {
  if (typeof value !== 'string') return { directiveCount: 0, sources: [] };
  const directives = value.split(';').map((entry) => entry.trim().split(/\s+/)).filter((entry) => entry[0]);
  const direct = directives.filter((entry) => entry[0].toLowerCase() === 'connect-src');
  const effective = direct.length > 0
    ? direct
    : directives.filter((entry) => entry[0].toLowerCase() === 'default-src');
  return {
    directiveCount: direct.length,
    usesDefaultSrcFallback: direct.length === 0 && effective.length > 0,
    sources: [...new Set(effective.flatMap((entry) => entry.slice(1)))].sort(),
  };
}

function firebaseCspFacts(projectRoot) {
  const relativePath = 'firebase.json';
  const text = readText(projectRoot, relativePath);
  let config = null;
  if (text !== null) {
    try {
      config = JSON.parse(text);
    } catch {
      config = null;
    }
  }
  const cspHeaders = (config?.hosting?.headers ?? []).flatMap((entry) => {
    const headers = (entry.headers ?? []).filter(
      (header) => String(header.key).toLowerCase() === 'content-security-policy',
    );
    return headers.map((header) => ({
      source: entry.source ?? null,
      ...parseCspConnectSources(header.value),
    }));
  }).sort((left, right) => String(left.source).localeCompare(String(right.source)));
  const html = readText(projectRoot, 'web/index.html') ?? '';
  const cleanHtml = html.replace(/<!--[\s\S]*?-->/g, '');
  return {
    hostConfigurationPath: relativePath,
    hostConfigurationPresent: text !== null,
    cspHeaders,
    htmlMetaCspPresent: /<meta\b[^>]*http-equiv\s*=\s*["']Content-Security-Policy["']/i.test(cleanHtml),
    hostedResponseHeaderCapture: 'not_observed',
  };
}

export function inspectPlatformNetworkConfiguration(projectRoot = root) {
  const androidSourceRoot = path.join(projectRoot, 'android/app/src');
  const manifestPaths = listFiles(androidSourceRoot, (name) => name === 'AndroidManifest.xml')
    .sort((left, right) => left.localeCompare(right));
  const networkSecurityConfigPaths = listFiles(androidSourceRoot, (name) =>
    /^network_security_config.*\.xml$/i.test(name),
  ).map((absolutePath) => ({
    path: path.relative(projectRoot, absolutePath).split(path.sep).join('/'),
    sha256: sha256(readFileSync(absolutePath, 'utf8')),
  })).sort((left, right) => left.path.localeCompare(right.path));
  const gradle = readText(projectRoot, 'android/app/build.gradle.kts') ?? '';
  const targetSdkExpression = gradle.match(/^\s*targetSdk\s*=\s*([^\r\n]+)/m)?.[1]?.trim() ?? null;
  const gradleNetworkOverrides = gradle
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split(/\r?\n/)
    .map((line) => line.replace(/\/\/.*$/, '').trim())
    .filter((line) => /usesCleartextTraffic|networkSecurityConfig|cleartextTrafficPermitted/i.test(line));
  const sourceManifests = manifestPaths.map((absolutePath) => sourceManifest(projectRoot, absolutePath));
  const apple = {
    ios: plistNetworkFacts(
      projectRoot,
      'ios',
      'ios/Runner.xcodeproj/project.pbxproj',
      'IPHONEOS_DEPLOYMENT_TARGET',
    ),
    macos: plistNetworkFacts(
      projectRoot,
      'macos',
      'macos/Runner.xcodeproj/project.pbxproj',
      'MACOSX_DEPLOYMENT_TARGET',
    ),
    bundleNetworkCapture: 'not_observed',
  };
  return {
    schemaVersion: 1,
    evidenceScope: 'repository_source_configuration_only',
    android: {
      gradlePath: 'android/app/build.gradle.kts',
      gradlePresent: readText(projectRoot, 'android/app/build.gradle.kts') !== null,
      targetSdkExpression,
      resolvedTargetSdk: null,
      gradleNetworkOverrides,
      sourceManifests,
      networkSecurityConfigFiles: networkSecurityConfigPaths,
      mergedManifestCapture: 'not_observed',
    },
    apple,
    web: firebaseCspFacts(projectRoot),
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(inspectPlatformNetworkConfiguration(), null, 2));
}
