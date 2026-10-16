# Web upgrade demo — synthetic meal journey

This is a repeatable local walkthrough script, approximately 90 seconds. It is not a completed video or a mobile-device test. Use only the app's **Tools → Synthetic meal journey** (`餐食流程合成试用`). That page creates a fresh in-memory service graph and nested navigation, so its food records, meal history and drafts are isolated from ordinary owner storage. Reset recreates that entire trial.

## Before capture

1. Start the locally built Web candidate. The standalone entry below opens the same synthetic journey immediately. Record its working-source identity and build identity using the steps below.
2. Use an empty browser profile and check the full frame for account names, bookmarks, private notifications and local filenames. A source digest does not perform visual privacy review.
3. Open the synthetic journey and choose Reset. Confirm only the single synthetic history meal is present. The FDC-shaped food is explicitly fabricated; it is not a USDA record.

## Approximately 90-second script

| Time | Action | Narration / expected visible result |
| --- | --- | --- |
| 0–10 s | Show trial title and isolation notice. | “This educational trial uses synthetic data in separate memory.” |
| 10–25 s | Reuse the synthetic history meal into a new entry. | “The previous meal stays unchanged. This creates a new draft.” |
| 25–40 s | Confirm the intended time and quantity; open Source portion and missing data. | “The source-bound example has 10 g protein per 100 g. Its synthetic cup is 160 g, so this preview should show 16 g protein; this is a calculation, not a dietary recommendation.” |
| 40–55 s | Leave the entry and reopen it; show restored draft, then save. | “The draft survives this page interruption. Saving checks current inputs again and creates a new record.” |
| 55–70 s | Show the saved meal and the source/missing-information entry. | “Captured missing fiber/sodium remain unknown. The source and basis explain the displayed values.” |
| 70–82 s | Begin an entry with Synthetic unknown food and open the preview. | “Unknown data and unsupported sources stay withheld. The app does not estimate a value to fill this gap.” |
| 82–90 s | Return to the trial and Reset. | “Reset clears this isolated trial. These engineering checks do not establish clinical validity.” |

Confirm the actual quantity selected before narrating 16 g: the independent relationship is `10 × 160 / 100 = 16 g`. If the source/quantity has changed, record the new expectation and rebuild instead of reusing old narration. This script does not measure efficiency or human comprehension. Record task steps/times separately if a real usability observation is later arranged.

## Build and local evidence identity

Run the following in the active repository. The first command records the source inventory without treating an existing build as verified evidence:

```sh
node tool/generate_upgrade_delivery_index.mjs
flutter build web --release -t lib/main_synthetic_meal_demo.dart --no-web-resources-cdn --dart-define=PARKINSUM_BACKEND=local
node tool/generate_upgrade_delivery_index.mjs --expected-source=<sourceDigest-from-first-command>
```

The final command refuses a changed source inventory. It produces `build/upgrade_delivery/latest.json` and `latest.md`, binding the committed HEAD separately from the dirty working-source digest and collecting Web artifact/NOTICE hashes. Existing screenshots are inventoried by file identity; their relationship to the displayed build still requires capture provenance and full-image review. Capture approved synthetic screenshots under `build/upgrade_delivery/screenshots/`, then repeat the final inventory command.

The generator also writes `build/upgrade_delivery/flutter-lock.spdx.json`: an SPDX 2.3 inventory of the current 138 packages in `pubspec.lock`, including development/build dependencies. It records lockfile package identities, hosted-package purl identifiers and archive checksums where available. Declared/concluded licenses are `NOASSERTION`; the inventory does not determine license compliance, which packages reach the compiled Web binary, or SDK contents. Web `NOTICES` has a separate artifact hash. Regenerate this inventory when the lockfile changes; the number above describes this candidate's lockfile, not a fixed release requirement.

The source and screenshots may be uncommitted; generated files are ignored local evidence. This index is neither a signature nor remote CI attestation, and it does not claim mobile binaries, independent review, real notification delivery or online publication. The final integration report supplies actual build/browser results; the existence of this script is not a passed result.

See [implementation status](NEXT_UPGRADE_PLAN.md#8-实际实施状态2026-09-29), [baseline evidence scopes](UPGRADE_BASELINE_RECONCILIATION.md), [importer source semantics](IMPORTER_DATA_RESEARCH_2026-09-29.md), and [Web restore limits](PORTABLE_WEB_RESTORE_BOUNDARY.md).
