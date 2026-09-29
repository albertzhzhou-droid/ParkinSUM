import assert from 'node:assert/strict';
import test from 'node:test';

import {
  evaluateMatrixReport,
  responseContentType,
} from './run_web_reflow_matrix.mjs';

function result(overrides = {}) {
  return {
    id: 'zoom-equivalent-400',
    width: 320,
    probe: {
      viewport: { width: 320, height: 720 },
      document: { horizontalOverflow: 0 },
      semanticsEnabled: true,
      horizontalViolations: [],
      targetAuditFailures: [],
      undersizedTargets: [],
      focus: { atLeastPartiallyVisible: true },
      ...overrides,
    },
  };
}

test('passing artifact probe has no failures', () => {
  assert.deepEqual(evaluateMatrixReport({ results: [result()] }), []);
});

test('page overflow and hidden focus fail closed', () => {
  const failures = evaluateMatrixReport({
    results: [
      result({
        document: { horizontalOverflow: 12 },
        focus: { atLeastPartiallyVisible: false },
      }),
    ],
  });
  assert.ok(failures.some((item) => item.includes('page horizontal overflow')));
  assert.ok(failures.some((item) => item.includes('focus is not visibly retained')));
});

test('uncontained semantics and undersized targets fail closed', () => {
  const failures = evaluateMatrixReport({
    results: [
      result({
        horizontalViolations: [{ label: 'offscreen' }],
        undersizedTargets: [{ label: 'tiny' }],
      }),
    ],
  });
  assert.ok(failures.some((item) => item.includes('semantic nodes')));
  assert.ok(failures.some((item) => item.includes('under 24 CSS px')));
});

test('viewport mismatch and absent semantics fail closed', () => {
  const failures = evaluateMatrixReport({
    results: [
      result({
        viewport: { width: 321, height: 720 },
        semanticsEnabled: false,
      }),
    ],
  });
  assert.ok(failures.some((item) => item.includes('viewport width')));
  assert.ok(failures.some((item) => item.includes('semantics tree unavailable')));
});

test('Wasm entry modules and engine resources use browser-safe MIME types', () => {
  assert.equal(responseContentType('/main.dart.mjs'), 'text/javascript; charset=utf-8');
  assert.equal(responseContentType('/main.dart.wasm'), 'application/wasm');
  assert.equal(responseContentType('/assets/icon.woff2'), 'font/woff2');
  assert.equal(responseContentType('/unknown.bin'), 'application/octet-stream');
});
