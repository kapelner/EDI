# Real observational datasets for EDI's comprehensive test/simulation database

Sourced 2026-10-03, via exhaustive CRAN package search (8 parallel search passes
plus dedicated verification passes for randomization status, duplicate
resolution, and CRAN package availability — see "Methodology" below), as the
observational counterpart to `experimental_datasets.md`. Unlike that catalog,
every dataset here is a **fixed, non-randomized two-arm comparison**: the group
(`w`) column was never assigned by an experimenter according to a known
probability law. There is therefore **no design to replay or compare** — these
exist to validate and compare **inference methods** on genuine observational
data, via EDI's `ObservationalDesign` class
(`w` supplied via `assign_w_to_all_subjects(w_precomputed = ...)` or
`overwrite_all_subject_assignments()`), not to compare randomization schemes.

Two intended usage modes (not mutually exclusive), parallel to
`experimental_datasets.md`'s modes 1/3 (mode 2, "real assignment replay with a
synthetic response," does not apply here — there is no randomization mechanism
to validate against, so a synthetic response adds nothing a real one doesn't
already give):
1. **Covariate-source only** — real baseline covariates, synthetic group and
   response with known truth, same pattern as `_dataset_load.R`'s existing 14
   ML-benchmark sources.
2. **Full real replay** — real covariates, real (observed, non-randomized)
   group membership, real outcome, no synthetic component. No known ground
   truth (nothing to validate coverage against), but genuine case-study
   evidence for comparing how different inference methods (e.g. outcome
   regression, propensity-weighting-flavored approaches available through
   `ObservationalDesign`, or naive mean-difference) handle the same real
   confounded comparison. One evaluation per method, not a Monte Carlo loop —
   does not fit `comprehensive_tests.R`'s replicate-based structure.

## Methodology

**Search:** 8 parallel searches (Haiku-model agents) across CRAN package
documentation/vignettes/reference manuals, each targeting a domain likely to
contain real two-arm observational data: epidemiology/public health, survival
analysis, econometrics (`wooldridge`/`AER`/`Ecdat`/`causaldata`), medical/
clinical textbook packages, general statistics textbooks, count-response
packages, ordinal-response packages, and agriculture/ecology. Together they
returned ~200 raw candidate (package, dataset) pairs before deduplication.

**Verification, not just search** — three further passes, because a search
agent's own "why observational" justification repeatedly turned out to be
wrong or unverified on inspection:
1. **Randomization-status re-check.** Several candidates returned as
   "observational" are in fact randomized or experimentally manipulated on
   closer inspection of the *original study* (not just the R package's
   one-line doc): `discSurv::crash2` (the CRASH-2 trial — tranexamic acid vs.
   placebo, a large, famous RCT), `KMsurv::drughiv`-type ACTG-style drug
   combination trials, `HSAUR2/HSAUR3::respiratory` (explicitly a randomized
   trial; the returning agent's own text flagged this), `ordinal::soup`
   (experimenter-controlled product presentation in an A-not-A sensory
   protocol), and `glmmTMB::Owls` (Roulin & Bersier's food-treatment was a
   researcher-imposed, reversed crossover manipulation, confirmed against the
   original *Animal Behaviour*-family study) — **all excluded**. Conversely,
   `wooldridge::injury` (Meyer, Viscusi & Durbin 1995, workers'-comp benefit
   increases — a documented *natural experiment*, not randomized) and
   `KMsurv::burn` (a burn unit's before/after *protocol change*, Ichida et al.
   1993 — moderate confidence only, flagged in its row below) were confirmed
   genuinely non-randomized and kept.
2. **Duplicate resolution.** Several "different" candidates turned out to be
   the same underlying study re-shipped across packages: `MASS::Melanoma` ≡
   `ISwR::melanom` (same 205-patient Odense cohort), `MASS::birthwt` ≡
   `aplore3::lowbwt` (same Baystate Medical Center 1986 study, carried across
   Hosmer & Lemeshow editions), `boot::channing` ≡ `asaur::ChanningHouse` ≡
   the `KMsurv`-referenced version (same Channing House retirement-community
   data, Hyde 1980), `epitools::oswego` ≡ `epiDisplay::Oswego` (same 1940 CDC
   EpiInfo outbreak-investigation teaching data). One canonical package kept
   per study; the alternates dropped (not listed as separate rows). Confirmed
   genuinely *different* despite superficial topic overlap: `MASS::birthwt`
   (Massachusetts, 1986, n=189) vs. `mosaicData::Gestation` (California CHDS
   cohort, 1961-62, n=1236) vs. `wooldridge::bwght` (1988 NHIS, n=1388) — all
   three kept.
3. **CRAN availability.** `ElemStatLearn` and `MedDataSets` are both removed
   from CRAN (`MedDataSets` for "misrepresentation of authorship" —
   2026-08-13) — both avoided entirely rather than sourced via the Archive/
   fallback, given the latter's removal reason. `likert::MathAnxietyGender`
   is a pre-aggregated 28-row summary table, not raw per-subject data —
   excluded. `ormPlot::educ_data`, returned by a Haiku search pass for a
   package whose actual stated purpose is *plotting* ordinal-regression
   output (not shipping survey data), could not be independently confirmed to
   exist with the claimed structure — excluded on low confidence rather than
   risk an unverified entry.

**Also excluded, independent of randomization/duplication:** candidates whose
natural "two-arm" column is actually a continuous exposure forced into two
bins (`boot::nodal`'s multiple binary predictors with no single natural group,
`carData::Wells`'s continuous arsenic level), candidates with 3+ natural
unordered group levels and no clean 2-level subset (`carData::Prestige`/
`Duncan`'s 3-category occupation type), candidates with no natural group/
exposure column at all (`carData::Freedman`, `MASS::biopsy`), state/year
*ecological panel* data where the unit of analysis is a jurisdiction-year, not
a subject (`AER::Fatalities`/`Guns`, most `wooldridge` crime/price panels,
`causaldata::abortion`), and `asaur::prostateSurvival` (explicitly documented
as *simulated* to match SEER-Medicare characteristics, not real patient
records — inconsistent with this catalog's "real observed outcomes" basis,
unlike every other row below).

**Required R packages: none**, same no-`install.packages()` policy as
`experimental_datasets.md` — every CRAN package below is fetched by the same
`cran_download_dataset_as_csv()` tarball-only mechanism (see that file for the
full download mechanism description; `download_experimental_datasets.R` is
intended to be extended to also read this table, not yet done — see TODO at
the bottom).

## Licensing

Same note as `experimental_datasets.md`: all datasets below are CRAN/
GitHub-packaged data (no ICPSR/openICPSR/Dataverse sources were found to fit
this catalog's criteria in this search pass), already published specifically
as reusable R package data under their own stated licenses — not something
newly redistributed by EDI.

## Dataset table

`p` = baseline covariates only (group, outcome, and ID columns excluded). `~`
marks a count that required judgment calls (e.g. multi-wave/longitudinal
columns) rather than an unambiguous count.

**Group Assignment column**: how the two-level `w` column arose, since there
is no randomization mechanism to document (contrast with
`experimental_datasets.md`'s Design column). Always non-randomized by
construction of this catalog (see Methodology); the text says *what kind* of
observational process produced the grouping (self-selection, clinical
indication, geography, pre-existing demographic trait, natural/policy
variation, matched case-control sampling, etc.), and flags the one row
(`KMsurv::burn`) kept at moderate rather than high confidence.

**Censoring column** (survival responses only; `n/a` otherwise): `right` for
loss-to-follow-up/administrative end-of-study censoring (the overwhelming
majority of observational survival cohorts below — a subject's event either
occurs or they are known event-free up to their last observed time, with no
information about what happens after), `left`, `interval` (event known only
to have occurred within a window, e.g. between two periodic follow-up visits),
or combinations. Determined from each dataset's documented follow-up design;
where follow-up is via periodic visits rather than continuous monitoring
(making exact event timing an interval rather than a point), both `right` and
`interval` are listed with a note.

**Response Variable column**: same grammar as `experimental_datasets.md`
(`;` separates type groups matched to `Response Type`'s ` + ` groups; `,`
separates outcomes within a group; `/` joins the columns of one outcome;
parenthetical text is a comment; every outcome names a `backticked` column).

Pinning rule: installed/current CRAN package version, checked 2026-10-03.

| Tier | Category | Dataset | Source | Version | License | n | p (covariates) | w (group column) | Response Variable | Response Type | Censoring | Group Assignment | Description |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Core | Causal inference | `nhefs` | CRAN: causaldata | 0.1.5 | MIT | 1,566 | ~20 | `qsmk` (quit smoking yes/no) | `wt82_71` | continuous | n/a | Self-selected smoking cessation between two NHANES follow-up waves | Hernán & Robins' "Causal Inference" textbook flagship dataset: weight change 1971-1982 by smoking-cessation status |
| Core | Causal inference | `cps_mixtape` | CRAN: causaldata | 0.1.5 | MIT | 15,992 | ~10 | `treat` (NSW job-training participant vs. CPS comparison) | `re78` | continuous | n/a | Self-selected program participation; CPS survey respondents as non-experimental comparison group | Non-experimental CPS comparison group for the LaLonde (1986) job-training literature — the observational counterpart to `experimental_datasets.md`'s `lalonde.exp` |
| Core | Medicine | `nafld1` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 17,549 | ~6 | case (NAFLD diagnosis yes/no, 4 matched controls per case) | `futime`/`status` | survival | right | Population-based registry match (Olmsted County); NAFLD status is a clinical diagnosis, not assigned | Non-alcoholic fatty liver disease population cohort followed 1997-2014 for mortality/metabolic/cardiac endpoints |
| Core | Medicine | `flchain` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 7,874 | ~6 | `sex` | `futime`/`death` | survival | right | Naturally occurring demographic trait | Mayo Clinic serum free-light-chain assay cohort; relationship between FLC level and mortality in a population-based sample aged 50+ |
| Core | Medicine | `mgus2` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 1,341 | ~7 | `sex` | `futime`/`death` (competing: `ptime`/`pstat` for progression to malignancy) | survival | right | Naturally occurring demographic trait | Natural-history follow-up of monoclonal gammopathy (MGUS) patients, competing risks of malignant progression vs. death |
| Core | Medicine | `rotterdam` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 2,982 | ~10 | `hormon` (hormonal therapy yes/no) | `dtime`/`death` (and `rtime`/`recur`) | survival | right | Clinical indication, not randomized | Rotterdam Tumor Bank breast-cancer surgical cohort (1978-1993), hormonal therapy use and prognostic markers |
| Core | Medicine | `gbsg` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 686 | ~7 | `hormon` | `rfstime`/`status` | survival | right | Clinical indication, not randomized | German Breast Cancer Study Group node-positive registry, hormone-receptor and therapy status |
| Core | Medicine | `heart` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 103 | ~4 | `transplant` (received a heart transplant yes/no) | `start`/`stop`/`event` | survival | right | Organ-availability waiting list, not randomized | Stanford Heart Transplant program waiting-list cohort — the classic textbook example of a time-dependent, non-randomized treatment indicator |
| Core | Medicine | `lung` | CRAN: survival | 3.8.6 | LGPL (>= 2) | 228 | ~5 | `sex` | `time`/`status` | survival | right | Naturally occurring demographic trait | NCCTG advanced lung-cancer cohort (the shipped extract carries no randomized treatment-arm column — only demographic/performance covariates) |
| Core | Medicine | `bmt` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 137 | ~4 | `group` (graft/disease risk category: ALL vs. AML-low-risk vs. AML-high-risk, usable as a 2-level subset) | multiple disease-free-survival `t2`/`d3` | survival | right | Clinical risk classification at transplant, not randomized | Bone-marrow-transplant recovery cohort, patient risk stratification and relapse-free survival |
| Core | Medicine | `kidney` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 119 | ~1 | `type` (surgically placed vs. percutaneous catheter) | `time`/`delta` | survival | right | Clinical indication, not randomized | Dialysis-patient cohort, catheter placement method and time to first catheter-related infection |
| Core | Medicine | `kidtran` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 863 | ~3 | `gender` | `time`/`delta` | survival | right | Naturally occurring demographic trait | Kidney-transplant recipient cohort, demographic covariates and time to death |
| Core | Medicine | `larynx` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 90 | ~2 | `stage` (recode to 2 levels, e.g. I-II vs. III-IV) | `time`/`delta` | survival | right | Clinical disease stage at diagnosis, not randomized | Larynx-cancer cohort, disease stage and time to death |
| Core | Medicine | `hodg` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 43 | ~2 | `gtype` (allogeneic vs. autologous graft) | `time`/`delta` | survival | right | Donor-availability/clinical decision, not randomized | Lymphoma graft-recipient cohort, graft type and time to death/relapse |
| Core | Medicine | `alloauto` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 90 | ~1 | `type` (allogeneic vs. autologous) | `time`/`delta` | survival | right | Donor-availability/clinical decision, not randomized | Leukemia graft-recipient cohort, graft type and leukemia-free survival |
| Core | Medicine | `tongue` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 80 | ~1 | `type` (tumor DNA profile: aneuploid vs. diploid) | `time`/`delta` | survival | right | Naturally occurring tumor biology, not assigned | Tongue-cancer cohort, tumor DNA ploidy and time to death |
| Core | Medicine | `allograft` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 34 | ~1 | `match` (HLA skin-match yes/no) | `time`/`rejection` | survival | right | Naturally occurring immunological fact, not assigned | Graft cohort, HLA tissue-match status and time to rejection |
| Core | Medicine | `std` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 877 | ~8 | `race` (or other recorded exposure) | `time`/`rinfct` | survival | right + interval (periodic clinic follow-up visits) | Observational STD-clinic cohort | Sexually-transmitted-disease cohort, demographic/behavioral covariates and time to reinfection |
| Core | Medicine | `bfeed` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 927 | ~6 | `race` (or `smoke`: maternal smoking yes/no) | `dur`/`delta` | survival | right | Naturally occurring maternal trait, not assigned | NLSY maternal cohort, breastfeeding duration by demographic/behavioral covariates |
| Core | Medicine | `burn` | CRAN: KMsurv | 0.1-5 | GPL (>= 2) | 154 | ~14 | `Z1` (bathing care method, before/after institutional protocol change) | `T3`/`D3` | survival | right | **Moderate confidence**: before/after institutional protocol change (Ichida et al. 1993), not documented as per-patient randomized — kept but flagged | Burn-unit cohort, bathing-protocol era and time to staphylococcus infection |
| Core | Medicine | `Melanoma` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 205 | ~4 | `sex` | `time`/`status` | survival | right | Naturally occurring demographic trait | Odense University Hospital malignant-melanoma surgical cohort (1962-1977) |
| Core | Medicine | `Aids2` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 2,843 | ~5 | `T.categ` (recode to 2-level, e.g. blood vs. other transmission route) | `death`/`status` | survival | right | Mode of HIV transmission, a recorded fact, not assigned | Australian AIDS surveillance registry (diagnoses to end of observation) |
| Expanded | Medicine | `channing` | CRAN: boot | 1.3-32 | Unlimited | 462 | ~2 | `sex` | `time`/`cens` | survival | right | Naturally occurring demographic trait | Channing House retirement-community mortality cohort (1964-1975), Hyde (1980) |
| Expanded | Medicine | `thoro` | CRAN: Epi | 2.63 | GPL (>= 2) | 2,470 | ~5 | `contrast` (Thorotrast-exposed vs. not) | `exitdt`/`exitstat` (constructed survival from entry/exit dates) | survival | right | Historical radiological-contrast exposure, not assigned | Cerebral-angiography cohort followed to 1992 for liver cancer/mortality after Thorotrast contrast exposure |
| Expanded | Medicine | `melanoma` | CRAN: biostat3 | 2.1 | GPL-3 | 7,775 | ~5 | `sex` | survival time/`status` | survival | right | Naturally occurring demographic trait | Population-based (Swedish) melanoma cancer-registry cohort |
| Expanded | Medicine | `colon` | CRAN: biostat3 | 2.1 | GPL-3 | 15,564 | ~6 | `sex` | survival time/`status` | survival | right | Naturally occurring demographic trait | Population-based colon-cancer registry cohort — distinct from `survival::colon`, which is a randomized trial already in `experimental_datasets.md` |
| Expanded | Medicine | `colrec` | CRAN: relsurv | 2.3-1 | GPL (>= 2) | 5,971 | ~4 | `sex` | `time`/`stat` | survival | right | Naturally occurring demographic trait | Slovene colon/rectal cancer registry cohort (1994-2000) |
| Expanded | Medicine | `hepatoCellular` | CRAN: asaur | 1.0-1 | GPL-2 | 227 | ~46 | `Grade` (recode to 2 levels) or `BCLC.stage` | `OS`/`Death`, `RFS`/`Recurrence` | survival | right | Clinical tumor classification, not assigned | Hepatocellular-carcinoma cohort with extensive clinical/molecular biomarkers, overall and recurrence-free survival |
| Expanded | Medicine | `ashkenazi` | CRAN: asaur | 1.0-1 | GPL-2 | 3,920 | ~2 | `mutant` (BRCA mutation carrier yes/no) | `age` (current age or age at cancer onset)/implicit censoring indicator | survival | right | Genetic status, not assigned | Ashkenazi Jewish women from BRCA-proband families (Struewing et al.), age-at-breast-cancer-onset by carrier status |
| Expanded | Public health | `diet` | CRAN: biostat3 | 2.1 | GPL-3 | 337 | ~6 | `job` (recode to 2 levels, e.g. driver vs. conductor) | person-years/`chd` | survival | right | Occupational category, not assigned | Morris et al. London-transport-worker cohort, occupational activity level and coronary-heart-disease incidence |
| Core | Medicine | `whiteside` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 56 | 1 | `Insul` (before vs. after cavity-wall insulation) | `Gas` | continuous | n/a | Same-house before/after comparison, not randomized | Weekly gas consumption vs. outdoor temperature, before and after insulating one house — a single-unit before/after design, weaker fit for between-subject causal comparison than the rest of this table |
| Core | Psychiatry | `Blackmore` | CRAN: carData | 3.0-5 | GPL (>= 2) | 945 (~236 subjects) | 2 | `group` (eating-disorder patient vs. control) | `exercise` | continuous | n/a | Hospital-admission status, not assigned | Retrospective exercise-history comparison of hospitalized eating-disorder patients vs. healthy controls |
| Core | Medicine | `Gestation` | CRAN: mosaicData | 0.20.4 | GPL-2 | 1,236 | ~10 | `smoke` (maternal smoking yes/no) | `wt`, `gestation` | continuous | n/a | Self-reported maternal behavior, not assigned | Child Health and Development Studies birth cohort (California, 1961-62); birth weight/gestation length by maternal smoking |
| Core | Medicine | `birthwt` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 189 | ~7 | `smoke` (maternal smoking yes/no) | `bwt`; `low` | continuous + incidence | n/a | Self-reported maternal behavior, not assigned | Baystate Medical Center (1986) low-birth-weight risk-factor study (Hosmer & Lemeshow) |
| Expanded | Economics | `bwght` | CRAN: wooldridge | 1.4-2 | GPL-3 | 1,388 | ~6 | `cigs` (recode to smoker yes/no) | `bwght` | continuous | n/a | Self-reported maternal behavior, not assigned | 1988 National Health Interview Survey birth-weight/smoking data (Mullahy 1997), a third, independent cohort from `birthwt`/`Gestation` above |
| Core | Medicine | `juul2` | CRAN: ISwR | 1.6 | GPL (>= 2) | 1,339 | ~6 | `sex` | `igf1` | continuous | n/a | Naturally occurring demographic trait | School-age reference sample, insulin-like growth factor by sex and pubertal stage |
| Core | Medicine | `bp.obese` | CRAN: ISwR | 1.6 | GPL (>= 2) | 102 | ~2 | `sex` | `bp` | continuous | n/a | Naturally occurring demographic trait | Mexican-American adults, blood pressure by sex and obesity |
| Core | Economics | `Males` | CRAN: Ecdat | 0.4-2 | GPL (>= 2) | 3,794 (~545 subjects, panel) | ~8 | `union` (union member yes/no) | `wage` | continuous | n/a | Self-selected union membership, not assigned | Vella & Verbeek young-males wage panel, union membership and log wage |
| Expanded | Economics | `TeachingRatings` | CRAN: AER | 1.2-15 | GPL-2 \| GPL-3 | 463 | ~5 | `gender` | `eval` | continuous | n/a | Naturally occurring demographic trait | University course/instructor evaluations, instructor gender and student evaluation score |
| Expanded | Economics | `beauty` | CRAN: wooldridge | 1.4-2 | GPL-3 | 1,260 | ~8 | `belavg` (looks below average yes/no) | `wage` | continuous | n/a | Rater-assessed physical trait, not assigned | "Beauty and the labor market" wage study (Hamermesh & Biddle 1994) |
| Core | Economics | `nodal` | CRAN: boot | 1.3-32 | Unlimited | 53 | ~4 | `acid` (elevated serum acid phosphatase yes/no) | `r` (nodal involvement) | incidence | n/a | Clinical lab result, not assigned | Prostate-cancer staging cohort, serum marker and lymph-node involvement |
| Core | Medicine | `glow500` | CRAN: aplore3 | 0.9 | GPL-3 | 500 | ~12 | `priorfrac` (prior fracture yes/no) | `fracture` | incidence | n/a | Clinical history, not assigned | GLOW postmenopausal-osteoporosis cohort, prior fracture and one-year fracture risk |
| Core | Medicine | `icu` | CRAN: aplore3 | 0.9 | GPL-3 | 200 | ~18 | `service` (medical vs. surgical admission) | `sta` (vital status at discharge) | incidence | n/a | Clinical admission category, not assigned | ICU admission cohort, service type and hospital-discharge survival |
| Core | Medicine | `burn1000` | CRAN: aplore3 | 0.9 | GPL-3 | 1,000 | ~6 | `flame` (flame-related burn yes/no) | `death` | incidence | n/a | Mechanism of injury, a recorded fact, not assigned | Multi-facility burn-injury cohort, injury mechanism and in-hospital mortality |
| Core | History | `TitanicSurvival` | CRAN: carData | 3.0-5 | GPL (>= 2) | 1,309 | 2 | `sex` | `survived` | incidence | n/a | Historical fact, not assigned | Titanic passenger/crew manifest, sex and survival |
| Expanded | Criminology | `Arrests` | CRAN: carData | 3.0-5 | GPL (>= 2) | 5,226 | ~5 | `colour` (recorded race, Black vs. White) | `released` (released with a summons) | incidence | n/a | Recorded demographic trait, not assigned | Toronto police drug-arrest records, race and release-with-summons outcome |
| Expanded | Psychology | `Cowles` | CRAN: carData | 3.0-5 | GPL (>= 2) | 1,421 | ~2 | `sex` | `volunteer` | incidence | n/a | Naturally occurring demographic trait | Cowles & Davis volunteer-subject-characteristics survey |
| Core | Finance | `Hmda` | CRAN: Ecdat | 0.4-2 | GPL (>= 2) | 2,381 | ~12 | `s13` (recode of race to 2 levels, Black vs. White) | `deny` | incidence | n/a | Recorded demographic trait, not assigned | Boston Federal Reserve mortgage-lending study, race and loan-denial decision |
| Expanded | Toxicology | `amlxray` | CRAN: faraway | 1.0.9 | GPL-2 \| GPL-3 | 83 (balanced matched case-control pairs) | ~6 | `Xray` (parental/child X-ray exposure yes/no) | `case` (AML case vs. matched control) | incidence | n/a | Recorded exposure history, not assigned | Matched case-control study of childhood AML and prenatal/postnatal X-ray exposure |
| Core | Public health | `esoph` | base R: datasets | 4.5.0 | Part of R | 88 strata (975 total subjects) | 2 | `tobgp` (recode to 2 levels, e.g. 0-9g vs. 30g+ daily) | `ncases`/`ncontrols` | proportion | n/a | Matched case-control sampling, not assigned | Breslow & Day (1980) Ille-et-Vilaine esophageal-cancer case-control study, aggregated by age/alcohol/tobacco strata |
| Expanded | Public health | `babyfood` | CRAN: faraway | 1.0.9 | GPL-2 \| GPL-3 | 6 strata (1,946 total infants) | 1 | `food` (recode to 2 levels: breast vs. bottle) | `disease`/`nondisease` | proportion | n/a | Self-selected maternal feeding choice, not assigned | Infant respiratory-disease incidence by feeding method, aggregated by sex |
| Core | Health economics | `DoctorVisits` | CRAN: AER | 1.2-15 | GPL-2 \| GPL-3 | 5,190 | ~10 | `gender` | `visits` | count | n/a | Naturally occurring demographic trait | 1977-78 Australian Health Survey, doctor visits by demographic/health covariates |
| Expanded | Health economics | `RecreationDemand` | CRAN: AER | 1.2-15 | GPL-2 \| GPL-3 | 659 | ~6 | `userfee` (holds an annual user fee yes/no) | `trips` | count | n/a | Self-selected fee status, not assigned | US recreational boat-trip demand survey |
| Expanded | Health economics | `rwm1984` | CRAN: COUNT | 1.3.6 | GPL (>= 2) | 3,874 | ~7 | `female` | `docvis` | count | n/a | Naturally occurring demographic trait | 1984 German Socioeconomic Panel health-care-utilization wave |
| Expanded | Health economics | `medpar` | CRAN: COUNT | 1.3.6 | GPL (>= 2) | 1,495 | ~7 | `hmo` (HMO-insured yes/no) | `los` (length of hospital stay) | count | n/a | Self-selected insurance plan, not assigned | Arizona Medicare inpatient (Medpar) claims, HMO status and length of stay |
| Expanded | Health economics | `azpro` | CRAN: COUNT | 1.3.6 | GPL (>= 2) | 3,589 | ~4 | `procedure` (CABG vs. PTCA) | `los` | count | n/a | Clinician/patient procedure choice, not assigned | Arizona cardiac-procedure claims, procedure type and length of hospital stay |
| Expanded | Ecology | `fishing` | CRAN: COUNT | 1.3.6 | GPL (>= 2) | 147 | ~3 | `period` (pre- vs. post-1990) | `totabund` | count | n/a | Before/after natural policy variation, not assigned | NMFS fishery-survey counts, pre- vs. post-1990 total catch abundance |
| Core | Science | `bioChemists` | CRAN: pscl | 1.5.9 | GPL-2 \| GPL-3 | 915 | ~4 | `fem` (gender) | `art` | count | n/a | Naturally occurring demographic trait | NSF survey of PhD biochemists, gender and publication-article count |
| Expanded | Education | `quine` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 146 | ~3 | `Lrn` (average vs. slow learner) | `Days` | count | n/a | Recorded student characteristic, not assigned | Australian school-absenteeism study, learner type and days absent |
| Expanded | Ecology | `Salamanders` | CRAN: glmmTMB | 1.1.12 | AGPL-3 | 644 | ~3 | `mined` (site previously mined yes/no) | `count` | count | n/a | Naturally occurring site history, not assigned | Appalachian stream-salamander survey, mining history and salamander counts |
| Core | Economics | `Fair` | CRAN: Ecdat | 0.4-2 | GPL (>= 2) | 601 | ~7 | `sex` | `nbaffairs`; `rate` (marriage rating) | count + ordinal | n/a | Naturally occurring demographic trait | Fair's (1978) extramarital-affairs survey, sex and self-reported affair count/marriage satisfaction |
| Core | Medicine | `retinopathy` | CRAN: catdata | 1.2.4 | GPL-2 | 613 | ~3 | `SM` (smoker yes/no) | `RET` | ordinal | n/a | Self-reported behavior, not assigned | Type-1-diabetic cohort, smoking status and retinopathy severity stage (3 levels) |
| Core | Sociology | `housing` | CRAN: MASS | 7.3-65 | GPL-2 \| GPL-3 | 72 (aggregated frequency table) | 2 | `Cont` (low vs. high resident contact) | `Sat` | ordinal | n/a | Housing-estate assignment pre-existing the survey, not assigned by researchers | Copenhagen Housing Conditions Survey, resident contact level and satisfaction (3 levels) |
| Core | Economics | `Mathlevel` | CRAN: Ecdat | 0.4-2 | GPL (>= 2) | 1,758 | ~4 | `sex` | `mathlevel`; `sat` | ordinal + continuous | n/a | Naturally occurring demographic trait | College-entry math-placement study, sex and math level/SAT score |