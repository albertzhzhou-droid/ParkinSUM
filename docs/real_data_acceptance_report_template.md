# Real Official Data Acceptance Report Template

Use this template for the operator pass that accepts a real official-source
snapshot. Do not use this report for local seed-only validation.

## Release Record

- Release id:
- Environment:
- Firebase project:
- App version:
- Operator:
- Clinical/domain reviewer:
- Technical reviewer:
- Date/time:

## Source Import

- Source family:
- Source organization:
- Source URL or file reference:
- Source publication/effective date:
- Import run id:
- Snapshot id:
- Parent snapshot id:
- Importer version or source reference:
- Artifact location:

## Readiness Summary

- Readiness command/report:
- Blocking count:
- Warning count:
- Review ticket count:
- Open high-severity ticket count:
- Artifact durability status:
- Rollback target:
- Publish guard result:
- Override reason, if any:

## Review Ticket Decisions

| Ticket id | Severity | Decision | Reviewer | Reason | Timestamp |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

## Recommendation Spot Checks

| Case | Inputs | Result | Evidence visible | Decision |
| --- | --- | --- | --- | --- |
| Levodopa/protein timing |  |  |  |  |
| MAOI/tyramine caution |  |  |  |  |
| Mineral/dairy timing |  |  |  |  |
| No-conflict meal |  |  |  |  |
| Missing data fallback |  |  |  |  |

## Firebase and Operations Checks

- Stage/prod Firestore live probe:
- Claims grant/removal verification:
- Backup/export path:
- Restore drill status:
- User export drill:
- User deletion drill:
- Monitoring/logging status:
- Browser smoke report:

## Accepted Risks

-

## Final Decision

Choose one:

- [ ] Hold release.
- [ ] Publish production_candidate.
- [ ] Publish with documented override.

Decision notes:
