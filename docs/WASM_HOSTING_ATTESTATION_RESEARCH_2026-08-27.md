# Wasm hosting attestation research — 2026-08-27

## Outcome

ParkinSUM now has a bounded, fail-closed local hosting attestation for a real
Flutter Web Wasm release artifact. It is an engineering proof for one Chromium
initial-setup state, not production-hosting, browser-support, clinical, or
regulatory evidence.

The final compared artifact was built with:

```sh
flutter build web --wasm --no-web-resources-cdn
```

Its aggregate attestation SHA-256 was
`de7d0231dc0e3de12703918623ca90c228b38e5a35cf99a4d30412b36efcd2fa`.
The generated JSON report binds the individual `main.dart.wasm`, Skwasm,
CanvasKit, bootstrap, service-worker, and response-body hashes as well as the
Flutter engine revision and build configuration.

## Same-artifact controlled comparison

The local runner served that exact directory through three independent HTTP
profiles and inspected observed responses plus the browser runtime:

| Profile | COOP | COEP | App ready | Isolated | SharedArrayBuffer | Wasm + Skwasm | JS fallback | Cross-origin engine | Console errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `plain_no_isolation` | absent | absent | yes | no | no | requested | no | none | 0 |
| `isolated_credentialless` | `same-origin` | `credentialless` | yes | yes | yes | requested | no | none | 0 |
| `isolated_require_corp` | `same-origin` | `require-corp` | yes | yes | yes | requested | no | none | 0 |

Each profile exposed the real Initial setup surface with 12 Flutter semantics
nodes and no Error/Retry surface. The non-isolated profile emitted Flutter's
expected warning and ran Skwasm single-threaded; absence of isolation did not
prevent startup. Both isolated profiles enabled `crossOriginIsolated` and
`SharedArrayBuffer` for the same bytes.

The runner also verifies `application/wasm`, no-store HTML, no-cache service
worker, immutable fingerprintable assets, critical response hashes, local
engine resources, and no silent dart2js fallback. Its evaluator has negative
tests for missing isolation, missing SharedArrayBuffer, wrong content type,
header drift, missing Wasm requests, JS fallback, cross-origin engine loading,
incomplete builds, and cache-policy drift.

## Wasm compatibility fixes made from runtime evidence

The first accurate Wasm launch exposed an unsupported database stub. Both
database factory conditional exports used `dart.library.html`, which does not
select the browser implementation for Wasm. They now use
`dart.library.js_interop`, following Dart's supported Web/Wasm conditional
import boundary.

The browser portable-export sink had the same selection issue and its Web
implementation imported unsupported `dart:html`. It now selects on
`dart.library.js_interop` and uses `dart:js_interop` plus `package:web`. A real
Chrome test proves that declining authorization creates no download side effect
and that an unsafe filename is rejected before Blob creation. An authorized
download and a cross-target export/import round trip remain open.

## Public, committed, local, and ignored state

- Public GitHub `main` and local `origin/main` were both observed at
  `2d7f02acff920e6ea3e96b1019d9debd61a7f37f` for this comparison.
- Local committed `HEAD` was
  `94e7ef30b64059ea6893a1ed431d15daac3ff859`, five commits behind
  `origin/main`.
- The relevant `firebase.json` Hosting headers were identical on public `main`
  and in the uncommitted local worktree: COOP is `same-origin`, while COEP is
  absent. Therefore neither source configuration is claimed to provide
  production cross-origin isolation.
- The attestation runner, tests, compatibility fixes, this document, and queue
  updates are uncommitted local changes. `build/` is ignored; generated reports
  are evidence for this worktree and are not public repository contents.

COEP was deliberately not added to production Hosting configuration. Firebase,
App Check, reCAPTCHA, frames, workers, and every other cross-origin dependency
must first be observed under a staging deployment. A header in source is not
evidence that a CDN, proxy, service worker, or browser received it.

## Remaining promotion gates

- Observe the exact deployed HTTPS responses, redirects, CDN/proxy behavior,
  MIME types, CSP, cache behavior, and cross-origin dependencies in staging.
- Exercise Firebase Auth, Firestore, App Check, reCAPTCHA, registration,
  registered-state recovery, recommendations, export, deletion, offline
  restart, service-worker update, and rollback on the hosted artifact.
- Cover supported Chromium releases and explicitly record Flutter's current
  Firefox, Safari, and iOS renderer/support limitations rather than inferring
  parity.
- Bind deployment, source revision, artifact, hosting manifest, renderer,
  fallback policy, and evidence with a signed release attestation.
- Keep a reviewed dart2js path until the supported-browser and product journey
  contract can promote Wasm without silently changing algorithms or data.
- Add a private Wasm symbolication pipeline and a public source-map/symbol leak
  gate. Production diagnostic assets must not be exposed by Hosting.

## Primary sources

- Flutter Web deployment: https://docs.flutter.dev/deployment/web
- Flutter WebAssembly support and build modes: https://docs.flutter.dev/platform-integration/web/wasm
- Dart migration from `dart:html` to `package:web`: https://dart.dev/interop/js-interop/package-web
- Dart `dart:js_interop` API: https://api.dart.dev/dart-js-interop/
- MDN `crossOriginIsolated`: https://developer.mozilla.org/en-US/docs/Web/API/Window/crossOriginIsolated
- MDN Cross-Origin-Embedder-Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy
