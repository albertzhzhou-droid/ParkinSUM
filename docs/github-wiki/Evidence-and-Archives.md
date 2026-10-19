# Evidence & archives

## Evidence archive

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/evidence-archive.svg" width="960" alt="An isometric archive of evidence sources. A wave passes through the cards, one is drawn out and its record opens: what it supports and what it does not. Sources cycle: FoodData Central 2025-04-24, FAO Food and Nutrition Paper 77, Nutt et al. 1989, Duan et al. 2021."></p>

Every model assumption points to a registered source with three parts: the **mechanism it supports**, its **limitation**, and a citation. The archive keeps negative findings. Nutt et al. 1989, for example, found that normal-diet LNAA fluctuations were *not* an important contributor for most participants, and the engine records that.

| Source type | Example | Used for | Not used for |
| --- | --- | --- | --- |
| Reference dataset | FDC 2025-04-24 | Nutrient values, factors, amino acids | Personal intake |
| Consensus standard | FAO FNP 77 | Energy identity | Proof of an error |
| Primary human study | Nutt 1989 | Naming a mechanism | A penalty or predictor |
| Analytical study | Duan 2021 | Presence and variability | A dose equivalent |

## Governance ledger

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/governance-archive.svg" width="960" alt="Context-of-use ledger records as an archive. Records 1, 26 and 27 are drawn out in turn; each is blocked pending evidence with no approval."></p>

Each change to the algorithm configuration appends one **context-of-use record**: the old and new configuration digests, what changed, and a release disposition. Earlier records are frozen as JSON fixtures, and tests require them to stay byte-exact. All 27 records are *blocked pending evidence*. Matching digests prove software identity only. They do not show scientific validity.

Read more: [evolution timeline](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/APP_EVOLUTION_TIMELINE.md)
