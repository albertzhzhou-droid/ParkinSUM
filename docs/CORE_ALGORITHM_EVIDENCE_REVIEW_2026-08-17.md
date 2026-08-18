# Core algorithm evidence review — 2026-08-17

## Review question

Which human and regulatory evidence can strengthen the direction, uncertainty,
and limitations of ParkinSUM's gastric-emptying, levodopa-opportunity, LNAA,
protein-distribution, and conflict models without turning a population result
into an individual prediction?

## Evidence hierarchy used

1. Official current drug labeling for formulation-specific food effects.
2. Primary human pharmacokinetic, gastric-emptying, and diet studies.
3. Consensus measurement standards.
4. Reviews only to locate primary work or describe mechanism direction.
5. ParkinSUM heuristic values remain explicitly tagged when no fitted,
   transportable coefficient exists.

## Evidence map and model consequence

| Evidence | Design and result used | What it changes | What it does **not** establish |
| --- | --- | --- | --- |
| Nutt et al., 1984, NEJM, doi:10.1056/NEJM198402233100802 | Nine selected patients with fluctuating motor state. Meals reduced peak plasma levodopa by 29% and delayed absorption by 34 minutes; selected LNAAs reversed response to infused levodopa without lowering plasma levodopa. | Adds primary support for two distinct pathways: meal-related absorption delay and LNAA transport competition. | Does not calibrate a universal meal penalty, dose rule, or individual response. |
| Doi et al., 2012, J Neurol Sci, doi:10.1016/j.jns.2012.05.010 | Thirty-one patients underwent levodopa PK and a 13C-octanoic-acid gastric-emptying breath test. Delayed emptying was more common with a later plasma levodopa peak. | Supports coupling gastric arrival to an opportunity window while keeping it uncertain. | Small association study; no per-meal predictive equation and no symptom prediction. |
| Hardoff et al., 2001, Mov Disord, doi:10.1002/mds.1203 | Scintigraphy in 51 participants with PD and 22 controls; PD groups had slower mean emptying with broad variation and subgroup differences. | Makes variability a first-class output and rejects a single “PD half-time.” | Group distributions overlap; diagnosis or individual calibration is not possible from app inputs. |
| Siebner et al., 2022, Front Neurol, doi:10.3389/fneur.2022.828069 | Solid-meal scintigraphy in 15 medicated participants with early PD and matched controls found no group-level delay; only one participant with PD met the delayed-emptying criterion. | Adds a necessary null finding and prevents the model from treating PD as a universal gastric-delay multiplier. | Small preliminary cohort in early disease while usual dopamine replacement continued; it cannot exclude effects in later disease, other medication states, or selected subgroups. |
| Abell et al., 2008, J Nucl Med Technol, doi:10.2967/jnmt.107.048116 | Consensus protocol: standardized low-fat egg-white meal with imaging at 0, 1, 2, and 4 hours. | Anchors the UI boundary: ParkinSUM is a sensitivity curve, not a clinical gastric-emptying test. | The protocol is not a formula for arbitrary meals. |
| Zinsmeister, Bharucha & Camilleri, 2012, Neurogastroenterol Motil, PMID:22812490 | Compared methods for estimating solid-meal half-time from scintigraphic retention measurements. | Supports measurement-method context and the distinction between a modeled half-time and observed retention checkpoints. | Does not supply ParkinSUM's 90-minute selected value, liquid parameters, or a Parkinson-specific distribution. |
| Camilleri et al., 2012, Neurogastroenterol Motil, PMID:22747676 | Healthy-participant scintigraphy reported 24.5% between-participant and 23.8% within-participant coefficients of variation for measured half-time. | Motivates showing model sensitivity to time-scale variation. | Healthy-participant measurement variation is not a Parkinson distribution; converting it to symmetric ±24% curves is a prototype heuristic, not an interval estimate. |
| Crevoisier et al., 2003, Eur J Pharm Biopharm, PMID:12551706 | Randomized two-way crossover in 19 healthy volunteers using one dual-release levodopa/benserazide product; a high-fat breakfast lowered mean Cmax and shifted mean Tmax from 1.0 to 3.1 hours. | Supports a wider formulation/food uncertainty window. | Product- and population-specific; magnitude cannot be assigned to all extended-release products. |
| Current DailyMed extended-release capsule labeling | A high-fat, high-calorie meal may delay absorption by about two hours for the labeled capsule; a high-protein meal may decrease absorption. | Requires formulation-specific provenance and prevents a generic ER curve from claiming exact kinetics. | A label for one product is not interchangeable with every tablet/capsule formulation. |
| Nutt et al., 1989, JNNP, doi:10.1136/jnnp.52.4.481 | Eleven fluctuating patients observed hourly on a normal hospital diet. Normal-diet LNAA fluctuations were not an important contributor for most participants. | Adds a necessary negative finding to the source registry and LNAA UI limitation. | Does not refute transport competition at high loads; does refute presenting ordinary variation as a universal strong effect. |
| Karstaedt & Pincus, 1992, Arch Neurol, doi:10.1001/archneur.1992.00530260049018 | Follow-up of 43 protein-sensitive fluctuating patients; 30 continued a redistribution diet for more than 12 months. | Supports “redistribution, not global minimization” as a direction for selected contexts. | Selected observational cohort; no unsupervised diet prescription, daily target, or broad effectiveness estimate. |

## Resulting model policy

- Gastric curves remain semi-mechanistic and deterministic for replay, but the
  UI calls them sensitivity curves and always surfaces uncertainty.
- Absorption “openness” remains unitless. It is never labeled concentration,
  fraction absorbed, bioavailability, or motor response.
- LNAA pressure remains a proxy. Actual amino-acid fields are preferred; the
  protein-source factor remains a prototype heuristic. The 1989 negative
  finding is shown next to the mechanism rather than omitted.
- The gastric arrival signal supplies LNAA-pressure **shape** only. It is
  peak-normalized before applying a bounded protein/LNAA amplitude so the
  unitless pressure and its thresholds share one scale. This fixes a prior
  fraction-per-minute versus unitless-threshold mismatch; it does not make the
  output a concentration or transport probability.
- Release-form food effects are not pooled into one exact coefficient. The
  executable absorption proxy is limited to the exact supported immediate-
  release tablet context; extended, controlled, delayed, and unknown release
  contexts abstain without a curve. Formulation-specific evidence defines the
  interpretation boundary but is not converted into a generic ER shape.
- Protein distribution is a bounded secondary objective. It cannot overpower
  worst modeled overlap and cannot prescribe restriction.
- Conflict score and candidate score are ordinal, decomposed, and replayable.
  Severity, confidence, and data completeness remain separate.

## Open calibration work

- Fit and validate a transparent population sensitivity envelope against
  published retention checkpoints before changing the central gastric curve.
- Add product-identity-specific release profiles only when label section,
  formulation, and version provenance are present.
- Validate any LNAA dose-relative transformation against independent human
  data before using it for more than trace context.
- No patient calibration, clinical effectiveness claim, or treatment timing
  recommendation is justified by the present evidence.

## Primary-source verification links

- [Nutt et al. 1984, PMID 6694694](https://pubmed.ncbi.nlm.nih.gov/6694694/)
- [Doi et al. 2012, PMID 22632782](https://pubmed.ncbi.nlm.nih.gov/22632782/)
- [Hardoff et al. 2001, PMID 11748735](https://pubmed.ncbi.nlm.nih.gov/11748735/)
- [Siebner et al. 2022, PMID 35280265](https://pubmed.ncbi.nlm.nih.gov/35280265/)
- [Zinsmeister et al. 2012, PMID 22812490](https://pubmed.ncbi.nlm.nih.gov/22812490/)
- [Camilleri et al. 2012, PMID 22747676](https://pubmed.ncbi.nlm.nih.gov/22747676/)
- [Crevoisier et al. 2003, PMID 12551706](https://pubmed.ncbi.nlm.nih.gov/12551706/)
- [Current product-specific DailyMed extended-release capsule label](https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=9ac804f1-7e15-48bc-8ae9-25181a629dd4&type=display)

These links verify the population, formulation, outcome, and magnitude claims
above. They do not change the model boundary: no cited source fits or validates
ParkinSUM as an individual pharmacokinetic or treatment-response predictor.
