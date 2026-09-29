import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  inspectAndroidApkManifest,
  parseAapt2XmlTree,
  scheduledNotificationBootReceiver,
} from './android_apk_manifest_inspection.mjs';

const androidUri = 'http://schemas.android.com/apk/res/android';

function attribute(name, value, indent = 8) {
  return `${' '.repeat(indent)}A: ${androidUri}:${name}(0x01010003)=${value}`;
}

function validTree({
  permission = true,
  exported = 'false',
  targetAction = true,
  otherReceiverAction = false,
  duplicateBootReceiver = false,
  commentPayload = null,
} = {}) {
  const lines = [
    `N: android=${androidUri} (line=2)`,
    '  E: manifest (line=2)',
    '    A: package="com.parkinsum.companion" (Raw: "com.parkinsum.companion")',
  ];
  if (commentPayload != null) lines.push(`      C: "${commentPayload}"`);
  if (permission) {
    lines.push(
      '      E: uses-permission (line=3)',
      attribute(
        'name',
        '"android.permission.POST_NOTIFICATIONS" (Raw: "android.permission.POST_NOTIFICATIONS")',
      ),
    );
  }
  lines.push(
    '      E: application (line=4)',
    `${' '.repeat(8)}A: ${androidUri}:label(0x01010001)="ParkinSUM Companion" (Raw: "ParkinSUM Companion")`,
    '          E: receiver (line=5)',
    attribute(
      'name',
      `"${scheduledNotificationBootReceiver}" (Raw: "${scheduledNotificationBootReceiver}")`,
      12,
    ),
    `${' '.repeat(12)}A: ${androidUri}:exported(0x01010010)=${exported}`,
  );
  if (targetAction) {
    lines.push(
      '              E: intent-filter (line=6)',
      '                  E: action (line=7)',
      attribute(
        'name',
        '"android.intent.action.BOOT_COMPLETED" (Raw: "android.intent.action.BOOT_COMPLETED")',
        20,
      ),
    );
  }
  if (duplicateBootReceiver) {
    lines.push(
      '          E: receiver (line=8)',
      attribute(
        'name',
        `"${scheduledNotificationBootReceiver}" (Raw: "${scheduledNotificationBootReceiver}")`,
        12,
      ),
      `${' '.repeat(12)}A: ${androidUri}:exported(0x01010010)=false`,
      '              E: intent-filter (line=9)',
      '                  E: action (line=10)',
      attribute(
        'name',
        '"android.intent.action.BOOT_COMPLETED" (Raw: "android.intent.action.BOOT_COMPLETED")',
        20,
      ),
    );
  }
  if (otherReceiverAction) {
    lines.push(
      '          E: receiver (line=11)',
      attribute(
        'name',
        '"example.OtherReceiver" (Raw: "example.OtherReceiver")',
        12,
      ),
      `${' '.repeat(12)}A: ${androidUri}:exported(0x01010010)=false`,
      '              E: intent-filter (line=12)',
      '                  E: action (line=13)',
      attribute(
        'name',
        '"android.intent.action.BOOT_COMPLETED" (Raw: "android.intent.action.BOOT_COMPLETED")',
        20,
      ),
    );
  }
  return `${lines.join('\n')}\n`;
}

describe('aapt2 indentation-tree parser', () => {
  test('preserves the real manifest/application/receiver/action hierarchy', () => {
    const parsed = parseAapt2XmlTree(validTree());

    assert.equal(parsed.namespaces.get('android'), androidUri);
    assert.equal(parsed.roots.length, 1);
    assert.equal(parsed.roots[0].localName, 'manifest');
    assert.deepEqual(
      parsed.roots[0].children.map((child) => child.localName),
      ['uses-permission', 'application'],
    );
    assert.equal(
      parsed.roots[0].children[1].children[0].children[0].children[0]
        .localName,
      'action',
    );
  });
});

describe('strict APK manifest inspection', () => {
  test('returns package, resolved label, permission, and bound boot receiver facts', () => {
    assert.deepEqual(
      inspectAndroidApkManifest(validTree(), {
        expectedPackageName: 'com.parkinsum.companion',
        expectedApplicationLabel: 'ParkinSUM Companion',
      }),
      {
        packageName: 'com.parkinsum.companion',
        applicationLabel: 'ParkinSUM Companion',
        postNotificationsDeclared: true,
        bootReceiver: {
          className: scheduledNotificationBootReceiver,
          exported: false,
          bootCompletedActionDeclared: true,
        },
      },
    );
  });

  test('comment text cannot impersonate permission or receiver descendants', () => {
    const tree = validTree({
      permission: false,
      targetAction: false,
      commentPayload:
        'E: uses-permission A: android:name=android.permission.POST_NOTIFICATIONS E: action A: android:name=android.intent.action.BOOT_COMPLETED',
    });

    assert.throws(
      () => inspectAndroidApkManifest(tree),
      /POST_NOTIFICATIONS must occur exactly once; found 0/,
    );
  });

  test('BOOT_COMPLETED on another receiver does not satisfy the target receiver', () => {
    assert.throws(
      () =>
        inspectAndroidApkManifest(
          validTree({ targetAction: false, otherReceiverAction: true }),
        ),
      /BOOT_COMPLETED must occur exactly once; found 0/,
    );
  });

  test('rejects an exported scheduled notification boot receiver', () => {
    assert.throws(
      () => inspectAndroidApkManifest(validTree({ exported: 'true' })),
      /android:exported must be false/,
    );
  });

  test('rejects duplicate target boot receivers as ambiguous', () => {
    assert.throws(
      () => inspectAndroidApkManifest(validTree({ duplicateBootReceiver: true })),
      /ScheduledNotificationBootReceiver must occur exactly once; found 2/,
    );
  });

  test('rejects a missing POST_NOTIFICATIONS permission', () => {
    assert.throws(
      () => inspectAndroidApkManifest(validTree({ permission: false })),
      /POST_NOTIFICATIONS must occur exactly once; found 0/,
    );
  });

  test('rejects expected package or label mismatches', () => {
    assert.throws(
      () =>
        inspectAndroidApkManifest(validTree(), {
          expectedPackageName: 'com.example.wrong',
        }),
      /manifest package mismatch/,
    );
    assert.throws(
      () =>
        inspectAndroidApkManifest(validTree(), {
          expectedApplicationLabel: 'Wrong label',
        }),
      /application label mismatch/,
    );
  });

  test('rejects duplicate required permission declarations', () => {
    const tree = validTree().replace(
      '      E: application (line=4)',
      `      E: uses-permission (line=30)\n${attribute(
        'name',
        '"android.permission.POST_NOTIFICATIONS" (Raw: "android.permission.POST_NOTIFICATIONS")',
      )}\n      E: application (line=4)`,
    );

    assert.throws(
      () => inspectAndroidApkManifest(tree),
      /POST_NOTIFICATIONS must occur exactly once; found 2/,
    );
  });
});
