# Purpose-bound consent receipts — research and engineering boundary

Reviewed: 2026-08-18

## Outcome

ParkinSUM now treats the optional Local AI path as a versioned purpose-bound
choice, not as a universal privacy or clinical consent. The worktree records a
grant or withdrawal event against an exact feature, purpose, notice version and
SHA-256 digest. The newest valid monotonic sequence controls the feature. The
evidence timestamp does not control event order, so setting the device clock
back cannot resurrect an older grant.

The Local AI adapter requires a current receipt and a process-local lease. It
checks that lease immediately before a loopback request and again before using
the response. Withdrawal or account clearing invalidates the lease first. A
late response from an older request is discarded.

This is an engineering accountability control. It is not a determination that
consent is the correct lawful basis in any jurisdiction, that a person has legal
capacity, or that the notice was understood.

## Evidence map

| Source | What it supports | Limit |
|---|---|---|
| [ICO: obtain, record and manage consent](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/how-should-we-obtain-record-and-manage-consent/) | Record who, when, how, what notice/version was shown, and whether consent was withdrawn; keep choices granular and withdrawal easy. | UK guidance is under continuing review and does not decide ParkinSUM's lawful basis. |
| [EU GDPR Article 7](https://eur-lex.europa.eu/eli/reg/2016/679/2016-05-04) | A controller relying on consent must be able to demonstrate it; withdrawal must be possible at any time and as easy as grant. | Engineering fields alone do not establish freely given or informed consent. |
| [Kantara Consent Receipt 1.1](https://kantarainitiative.org/download/consent-receipt-specification/) | Open pattern: a human-readable receipt with controller, purpose, notice and processing information can also have a structured representation. | ParkinSUM does not claim Kantara or ISO conformance; its schema is deliberately smaller. |
| [W3C DPV community work](https://www.w3.org/community/dpvcg/wiki/Main_Page) | Future machine-readable purpose, processing and consent-event terminology. | Community-group vocabulary is not a legal decision engine and mappings still need governance. |
| [Apple HIG: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/) | Ask in feature context, state the purpose specifically, and keep the choice reviewable in settings. | HIG guidance is not a substitute for cross-platform usability or legal review. |

## Current contract

- Receipt schema: `purposeBoundConsentReceiptSchemaVersion = 1`.
- Current feature: `local_ai_reranking`.
- Current purpose: loopback-only safe-whitelist reranking and wording polish.
- Default: denied.
- A missing receipt, malformed/future schema, duplicate or non-contiguous
  sequence, changed notice version/digest, or blocked ledger denies the feature.
- A legacy true boolean is retained only as a “review needed” signal and does
  not authorize Local AI.
- A blocked ledger cannot grant. The user can always create a fresh explicit
  withdrawal record to repair the safe-off state.
- The profile store owns the account boundary. Firestore currently limits the
  receipt list size, while the application performs exact per-receipt validation
  on read.

## Pattern transfer and open-source boundary

Kantara's open consent-receipt pattern influenced the separation between a
human notice and a structured event. No upstream code or schema was copied.
ParkinSUM uses its own small schema, identifiers and canonical digest. W3C DPV
is recorded as an interoperability research direction, not silently embedded
as if a vocabulary mapping had been reviewed.

## Residual risks and next work

1. Receipts are embedded in the profile mutation, not a server-authoritative
   append-only collection with operation ID, expected revision and durable
   acknowledgement-loss recovery.
2. Firestore rules bound the list but cannot prove every nested receipt field;
   a backend writer can create state that the app will correctly block but not
   prevent at write time.
3. The portable package currently exports only the effective Local AI choice,
   not the receipt history. A schema migration is required before claiming
   portable receipts.
4. Only Local AI uses the contract. Support-case upload, telemetry and caregiver
   coordination remain denied until each has a separate purpose and notice.
5. Notice body details are currently canonical English engineering text. Native
   translations, semantic-equivalence review, screen-reader order and human
   comprehension testing remain open.
6. Cross-device grant/revoke concurrency, offline retry, lost acknowledgement,
   backend failure and deletion/retention behavior need a durable mutation
   protocol and emulator/target-device evidence.
