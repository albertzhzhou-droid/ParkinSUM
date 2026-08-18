# Open-source pattern transfer review — 2026-08-17

## Scope and safety boundary

This review studies publicly documented architecture and product behavior. It
does **not** copy source code, clinical claims, datasets, survey instruments, or
visual identity. The second pass covers representative projects in each
relevant category; it is not a claim that every repository on the internet was
enumerated. Any future code or data reuse requires a separate file-level
license and attribution review. Source-available and noncommercial projects are
research references, not code donors. Open Food Facts data is governed
separately from its Dart SDK.

## Pattern map

| Reference project | Observed public pattern | ParkinSUM transfer | Status |
|---|---|---|---|
| [OpenMRS Core](https://github.com/openmrs/openmrs-core) | API/web separation, SDK and removable modules, rebuildable search index, operational monitoring | Keep deterministic algorithms behind a UI-independent SDK; rebuild catalog indexes from repository revisions | Implemented: `lib/algorithm_sdk/`, `CatalogSearchIndex` |
| [Open Food Facts Dart](https://github.com/openfoodfacts/openfoodfacts-dart) | Typed Dart SDK over JSON, explicit migration notes, product search/autocomplete, localized taxonomy access | Version every public algorithm/data envelope; normalize multilingual type-ahead locally; keep source/data licensing explicit | Implemented: schema catalog, SDK envelope, n-gram index |
| [Nightscout](https://github.com/nightscout/cgm-remote-monitor) | Queryable versioned data APIs, distinct entry/treatment/profile resources, sync identifiers, optional plugins | Keep sensitive payloads out of IDs, expose stable safe identifiers, append mutation history, separate optional presentation from the deterministic engine | Implemented: safe ID factory, append-only record history, algorithm registry |
| [OHIF Viewer](https://github.com/OHIF/Viewers) | Core features use the same extension/mode/service boundaries offered to external features; configuration is versioned | Treat Algorithm Observatory as a consumer of a stable engine/SDK rather than a second implementation; add new algorithm panels through registered descriptors | Implemented: 58-entry registry and SDK; only six descriptors currently have provider-backed production traces, and broader executable-provider coverage remains queued |
| [PK-Sim](https://github.com/Open-Systems-Pharmacology/PK-Sim) | Reusable building blocks separate individuals, populations, compounds, formulations, administration protocols, events, observers, and observed data; alternative model structures are explicit | Keep formulation, event, parameter-set, and model-structure identity replaceable and versioned; compare structural alternatives as read-only shadow models before production changes | Research queue: structural-uncertainty shadow models; GPLv2 code is not copied |
| [rxode2 event tables](https://nlmixr2.github.io/rxode2/reference/eventTable.html) | Ordered dosing and observation events carry explicit amount and time units rather than relying on implicit numeric conventions | Add unit-bearing fixtures and metamorphic conversion tests to the existing minute-axis and dose-context contracts | Implemented for the current mechanistic gate: minute/hour and mg/g/mcg metamorphic checks; broader algorithm-surface unit coverage remains queued |
| [HAPI FHIR](https://github.com/hapifhir/hapi-fhir) | Versioned models, validation layers, storage abstraction, lifecycle interceptors, partition-aware access | Maintain a machine-checked schema catalog, validate at storage boundaries, preserve append-only provenance, bind every patient collection to its owner | Implemented: schema contract, Firestore validators, atomic audit rows |
| [Take Your Meds](https://github.com/cucumberfalse/takeyourmeds) | Mobile-first conditional platform boundaries, actionable reminders, local intake journal, dedicated integration tests | Keep Web degradation explicit; add device-level registration, logging, notification-action, timezone, reboot and migration journeys | Queued: cross-platform integration harness |
| [mPower](https://github.com/ResearchKit/mPower) | Consent-oriented Parkinson research app combining surveys with sensor tasks; licensed instruments and shipping-only security components are intentionally absent from the public tree | Separate open implementation from non-redistributable instruments; never infer clinical scores from generic sensor capture | Research queue: sensor-biomarker sandbox |
| [ParaDigMa](https://github.com/biomarkersParkinson/paradigma) | Device- and context-bounded gait, tremor and pulse pipelines with peer-reviewed validation references and explicit sensor requirements | Preserve device, placement, sampling, firmware, missingness and pipeline provenance; fail closed outside validated context | Research queue: validated sensor adapter |
| [HealthLog](https://github.com/MBombeck/HealthLog) | Self-hosted web/native split, OpenAPI contract, passkeys, action reminders, forward-only migrations, operator backup guidance | Add an encrypted restore drill and commit-linked migration evidence; keep license restrictions out of implementation code | Queued: backup/restore recovery |
| [Table Habit / mHabit](https://github.com/FriesI23/mhabit) | Flutter local-first operation without a required account, native JSON import/export, Loop Habit migration, optional WebDAV sync, 18+ languages and RTL, and release channels across five desktop/mobile operating systems | Add a user-owned portable data package and isolated import preview; keep optional self-hosted synchronization separate from the clinical-like record and conflict-resolution policy | In progress: bounded, account-bound export plus no-write import preview; durable import/rollback, encryption, device round trips, and WebDAV remain open |
| [Open Wearables Health SDK](https://github.com/the-momentum/open_wearables_health_sdk) | Explicit background-task registration, anchored incremental reads, secure token storage, provider-specific permissions, and a custom self-hosted endpoint | If device data is researched, preserve anchor/cursor, permission, device, provider and background-run provenance; never convert generic phone data into a Parkinson score | Existing sensor-biomarker sandbox, strengthened context gate |
| [SparkyFitness](https://github.com/CodeWithCJ/SparkyFitness) | Multi-profile health aggregation, permissions, import/export and unified reports; project correctly labels itself source-available | Study family-permission and reporting behavior without copying restricted code; test aggregate invalidation after API writes | Existing caregiver/export queue plus integration regressions |
| [Acara Plate](https://github.com/acara-app/plate) | Asynchronous AI jobs, structured health context, user-confirmed natural-language logging, source-versus-estimate separation for food analysis | If multimodal capture is added, produce editable drafts, preserve field provenance and block ambiguous medication/allergen/unit data | Research queue: confirmation-first capture |

## Implemented contracts

1. `ParkinSumAlgorithmSdk` is UI-independent and returns a versioned envelope
   containing the engine and parameter-set versions.
2. `config/schema_catalog.json` is checked in CI-ready tooling and records the
   compatibility policy for public/persisted schemas.
3. user record mutations and `record_history` entries share one Firestore
   batch; history is create-only in security rules.
4. catalog search uses a revision-aware immutable n-gram index and verifies
   exact substring matches while preserving source order.
5. persistent shell and catalog pages subscribe to narrow value slices instead
   of rebuilding on every `AppState` notification.

## New transfer decisions from the second pass

1. **Device journeys, not more widget mocks.** The next test investment is a
   real `integration_test` matrix with device/OS, locale, accessibility,
   timezone, schema and commit metadata. Reminder actions, reboots and
   background delivery cannot be certified in a widget harness.
2. **Sensor algorithms need context-of-use gates.** mPower demonstrates the
   research-task model; ParaDigMa demonstrates that a pipeline should name the
   supported sensor configuration and validation evidence. ParkinSUM should
   not turn generic accelerometer data into a Parkinson score.
3. **All AI capture remains draft-first.** Natural-language or meal-photo
   parsing may reduce motor burden, but every extracted medication, dose, time,
   food, portion and nutrient value must remain editable and uncommitted until
   explicit confirmation. Reference values, estimates and user edits stay
   distinguishable.
4. **Restore is a feature, not a backup checkbox.** A backup capability is not
   accepted until an isolated restore runs migrations and verifies checksums,
   ownership, missingness and audit links.
5. **License is part of architecture review.** BSD, MIT and Apache references
   still require attribution review; GPL/AGPL, PolyForm, O'Saasy and other
   source-available licenses require product/legal decisions before reuse.
6. **Portability is independent from cloud accounts.** A local-first user must
   be able to produce a versioned, inspectable package and preview a migration
   before import. Optional WebDAV or self-hosted sync cannot bypass ownership,
   encryption, schema, conflict, missingness or audit checks.
7. **Background health reads are resumable jobs.** An adapter needs an anchored
   cursor, permission snapshot, device/provider identity, time-zone handling,
   retry boundary and last-success evidence. A successful SDK call is not
   evidence that the incoming sensor context matches a validated algorithm.
8. **A visual contract is not an executable trace.** The current atlas renders
   all 58 registered algorithms, but only six core registered mechanisms are
   emitted by the fixed-scenario production trace today. A live claim must bind
   to a provider, fixture schema, algorithm-specific view or table, source path,
   and executable test.
9. **Model structure and units are first-class inputs.** PK-Sim demonstrates
   replaceable building blocks and explicit structural alternatives; rxode2
   event tables make amount and time units part of the event contract.
   ParkinSUM will use these as architecture patterns only; they do not validate
   its simplified model or turn it into a PBPK/PK model.

## Deliberately deferred patterns

- A third-party extension loader is not justified yet: it would expand the
  trusted-code surface before a signed-extension and capability model exists.
- FHIR resource serialization is not claimed. ParkinSUM currently has versioned
  internal contracts, not demonstrated FHIR conformance.
- Public writable health APIs are not enabled. Authentication, App Check,
  owner binding, and semantic rules remain mandatory.
- Parkinson sensor-derived biomarkers are not added to recommendations. They
  require device/protocol validation, prospective governance and separate
  human-factors work.
- Natural-language and image capture are not permitted to write directly into
  the durable clinical-like record.

## Primary references reviewed

- OpenMRS repository navigation, SDK/modules, index rebuild, and monitoring:
  <https://github.com/openmrs/openmrs-core>
- Open Food Facts Dart typed API, migrations, search/autocomplete and data
  licensing notice: <https://github.com/openfoodfacts/openfoodfacts-dart>
- Nightscout API resources, sync identifier behavior and plugin model:
  <https://github.com/nightscout/cgm-remote-monitor>
- OHIF extension lifecycle and module types:
  <https://github.com/OHIF/Viewers/blob/master/platform/docs/docs/platform/extensions/index.md>
- HAPI FHIR modules and interceptor documentation:
  <https://github.com/hapifhir/hapi-fhir> and
  <https://hapifhir.io/hapi-fhir/docs/interceptors/built_in_server_interceptors.html>
- Take Your Meds product and architecture documentation:
  <https://github.com/cucumberfalse/takeyourmeds>
- mPower repository and redistribution boundary:
  <https://github.com/ResearchKit/mPower>
- ParaDigMa sensor requirements and scientific-validation index:
  <https://github.com/biomarkersParkinson/paradigma>
- HealthLog API, self-hosting and backup architecture:
  <https://github.com/MBombeck/HealthLog>
- Table Habit local-first, JSON migration, WebDAV, localization and
  cross-platform distribution: <https://github.com/FriesI23/mhabit>
- Open Wearables Health SDK anchored background sync and secure credential
  storage: <https://github.com/the-momentum/open_wearables_health_sdk>
- SparkyFitness feature/permission comparison and source-available notice:
  <https://github.com/CodeWithCJ/SparkyFitness>
- Acara Plate async architecture and estimate provenance:
  <https://github.com/acara-app/plate>
- PK-Sim model structures and reusable building blocks:
  <https://github.com/Open-Systems-Pharmacology/PK-Sim>
- rxode2 ordered event records with explicit amount/time units:
  <https://nlmixr2.github.io/rxode2/reference/eventTable.html>
