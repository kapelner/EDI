# Audit: Inference Classes vs. Experimental Practice in the Literature

Generated 2026-08-26. Three-part audit: (1) every concrete exported
inference class in `R/EDI/R/inference_*.R`, (2) every new inference class or
response type proposed in `new_feature_plans/`, (3) a literature survey of
what practitioners of randomized experiments in medicine, economics,
political science, tech A/B testing, psychology, education, criminology,
marketing, HCI and sociology actually use — then the gap between (3) and
(1)+(2), with a frequency comment per missing method.

Frequency labels come from cited methodological reviews where one exists
(e.g. "Cox in 97% of TTE-primary trials, Jachno et al. 2019"); otherwise
they are judgments from guidance documents and are marked "(estimate)".
Figures from different reviews cover different journals/years (2005–2026)
and top-journal samples overstate sophistication relative to the wider
literature.

---

## Part 1 — What EDI has today (103 concrete exported classes)

| Response type | Plain | KK matched | Total |
|---|---|---|---|
| All / response-agnostic | 3 | 2 | 5 |
| Continuous | 4 | 9 | 13 |
| Incidence | 14 | 11 | 25 |
| Proportion | 5 | 4 | 9 |
| Count | 8 | 5 | 13 |
| Survival | 8 | 11 | 19 |
| Ordinal | 11 | 8 | 19 |
| **Total** | **53** | **50** | **103** |

Coverage by family (abbreviated; full per-class catalog is in the class
registry and roxygen):

- **All:** Welch t, pooled t, Wilcoxon/Hodges-Lehmann; KK IVWC versions.
  Every class carries Wald + randomization + nonparametric/Bayesian
  bootstrap + jackknife inference contracts.
- **Continuous:** OLS (homoskedastic SE), Lin (2013) interacted OLS with
  HC2, robust M/MM regression, quantile regression; KK IVWC/OneLik of each,
  Bai adjusted-t (KK14/KK21), linear mixed model with pair random
  intercept.
- **Incidence:** RD via Wald / LPM / identity-binomial / Newcombe /
  Miettinen-Nurminen / g-computation; OR via logistic / probit / Fisher /
  McNemar / Zhang exact / conditional logit; RR via log-binomial / modified
  Poisson / g-computation; two legacy blocked-design estimators (CMH-style
  mean diff, Extended Robins); KK versions via clogit IVWC/OneLik, clogit+
  GLMM hybrids, GEE, pair-clustered g-comp and modified Poisson.
- **Proportion:** fractional logit, beta regression, zero/one-inflated beta,
  g-comp mean diff, logit-scale quantile regression; KK quantile IVWC/
  OneLik, fractional GEE, clogit+GLMM.
- **Count:** Poisson (ML / quasi / sandwich), negative binomial, hurdle and
  zero-inflated Poisson/NB; KK Poisson GEE, Poisson GLMM, conditional
  Poisson OneLik, hurdle IVWC/OneLik. **No exposure/person-time offset.**
- **Survival:** Cox, stratified Cox, Weibull AFT, dependent-censoring
  transformation model, log-rank, Gehan-Wilcoxon, KM median difference,
  RMST difference; interval censoring in Cox/log-rank/Gehan/KM; KK
  stratified-Cox and LWA marginal-Cox IVWC/OneLik, cluster-robust marginal
  Weibull, log-normal-frailty and Clayton-copula Weibull IVWC/OneLik, rank
  regression.
- **Ordinal:** proportional odds, partial PO, ordered probit/cloglog/
  cauchit, adjacent-category, continuation-ratio, stereotype logit, g-comp
  expected-score diff, Jonckheere-Terpstra (Mann-Whitney stochastic
  superiority), ridit; KK paired sign test, conditional adjacent-category,
  ordinal GEE, cumulative-link GLMM in four links.

Design side relevant to this audit: fixed and sequential two-arm designs,
blocking, KK matching-on-the-fly, `DesignFixedCluster` /
`DesignFixedBlockedCluster` (cluster-level randomization via
`randomizr::cluster_ra`), rerandomization, D-/optimal designs.
Randomization and bootstrap inference respect the randomization unit; there
is no general model-based cluster-robust-SE or random-cluster-intercept
GLMM/GEE outside the KK pair machinery.

**Where EDI is ahead of practice:** exact/randomization inference on every
class (econ uses it in a minority of papers, polisci as default);
interval-censored survival (practice ignores it, <2% of trials); beta /
zero-one-inflated / fractional models for proportions; hurdle and
zero-inflated counts; the whole KK matched-pair family; g-computation
marginal estimands for binary outcomes (only 21% of adjusted-RD trials use
standardization, Thompson et al. 2025); partial proportional odds and
stereotype logit (practitioners rarely check PO at all).

---

## Part 2 — What is already planned (`new_feature_plans/`)

| Plan | Response type | Proposed classes / models | Status |
|---|---|---|---|
| `nominal_response_type_report.md` | new `nominal` | Pearson χ²/G², focal-category contrast, baseline-category multinomial logit | decision-gated, v1.1.0 TODO-6 |
| `rank_choice_response_type_report.md` | `nominal` / new `ranking` | conditional logit (menu-varying choice), Plackett-Luce / Mallows | decision-gated, v1.1.0 TODO-6 |
| `semi_continuous_response_type_report.md` | `continuous` | hurdle log-normal / hurdle gamma two-part; Tobit second wave | decision-gated, v1.1.0 TODO-6 |
| `multivariate_response_type_report.md` | K endpoints | `InferenceMultiEndpointComposite` (Holm; Fisher/O'Brien global test); joint SUR/Hotelling explicitly deferred | decision-gated, v1.1.0 TODO-6 |
| `compositional_response_type_report.md` | new `compositional` | ILR → OLS wrapper, ILR-Hotelling/permutation; Dirichlet deferred | decision-gated, v1.1.0 TODO-6 |
| `longitudinal_repeated_measures_response_type_report.md` | new `longitudinal` | `InferenceLongitudinalGEE` (exch/AR1/indep), `InferenceLongitudinalGLMM` (random intercept); treatment×time / random slopes deferred | decision-gated, v1.1.0 TODO-6 |
| `censored_continuous_response.md` | `continuous` + right-censoring | Tobit kernel in OLS; Lin/quantile(`crq`)/robust/KK variants | v1.1.0 TODO-7 |
| `censored_count_response.md` | `count` + right-censoring | censored Poisson/NB; binned counts | v1.1.0 TODO-7 |
| `betaregscale_duplication.md` | `proportion` | interval-censored beta regression, variable dispersion | v1.1.0 TODO-7 |
| `interval_censored_survival_response_type_report.md` | `survival` | NPMLE/Turnbull Cox-analogue, stratified icenReg, current-status | decision-gated, v1.1.0 TODO-12 |
| `survival_quantile_regression.md` | `survival` | self-consistent-EM censored QR + KK IVWC/OneLik | approved 2026-08-26, TODO-15d |
| `count_quantile_regression.md` | `count` | jittered QR + KK IVWC/OneLik | approved 2026-08-26, TODO-15e |
| `kk_beta_regression_one_lik_derivation.md` | `proportion` KK | Beta GLMM / OneLik / IVWC | committed, TODO-15b |
| `full_glmm_for_weibull_frailty.md` | `survival` KK k-strata | frailty GLMMs generalized to k-wise clusters | proposed, not yet indexed |
| `multi_arm_designs.md` | all, K>2 arms | `arm_treated/arm_control`; `MultiArmInference` (Bonferroni/Holm/Dunnett); native K-arm classes demand-gated | v1.1.0 TODO-8 |
| `sequential_inference.md` | all | `SequentialMonitor`: alpha-spending (OBF/Pocock), Bayesian monitoring, anytime-valid confidence sequences, sequential randomization tests | scoping, v1.1.0 TODO-13 |
| corrections family (Firth, Cox-Snell, Cordeiro-McCullagh, Bartlett, Cordeiro-Ferrari, Lemonte, modified profile, ridge, median-bias) | existing classes | `estimate_type` / testing-type switches on existing estimators | decision-gated, TODO-5 |

Explicitly rejected in plans: incidence quantile regression; `crq()`
fast-path; native joint multivariate (SUR/Hotelling); Dirichlet regression;
beta-binomial; L1 penalties; bounded-score response type (docs only).

---

## Part 3 — What practitioners actually use (condensed)

### Medicine / clinical trials / epidemiology
Top methods (reviews: Jachno 2019; Thompson 2025; Selman 2024; Ren 2022;
Fiero 2016; Nevins 2024; Bell 2014; Ooms 2025; Wang 2023; Redfors 2024):
1. Cox PH + log-rank + KM (97%/88%/98% of TTE-primary top-journal trials)
2. Logistic regression (adjusted OR) for binary outcomes
3. ANCOVA / linear regression adjusted for baseline & strata (92% of UK CTU
   trials adjust)
4. MMRM / linear mixed models for repeated continuous outcomes (42% of
   OCTRU primaries; 43.5% of repeated-measure RCTs use any mixed/GEE)
5. ITT + complete-case missingness
6. Subgroup × treatment interaction forest plots
7. Unadjusted RD/RR; log-binomial (65–70%) and modified Poisson (23–29%)
   when RR is reported
8. Proportional odds for mRS / WHO scale (44% of ordinal-outcome trials;
   33% dichotomize)
9. Negative binomial for exacerbation / relapse / hospitalization rates
   (>70% in respiratory, estimate) — always with a person-time offset
10. Group-sequential alpha-spending interim monitoring (77% of CV trials
    with interims)
11. GEE (16% of CRTs) and 12. GLMM with random cluster intercept (52% of
    CRTs; 70% of stepped-wedge)
13. Per-protocol alongside ITT (non-inferiority: 42% report both)
14. Multiple imputation + MNAR sensitivity (8% MI; 35% any sensitivity)
15. Win ratio / hierarchical composites (68 RCTs 2012–24, 68% cardiology,
    growing fast), then Bayesian primary (~1% of phase III),
    standardization/g-comp (21% of adjusted-RD), RMST (<5%), Fine-Gray.
Competing risks: 77% of competing-risk-prone top-journal trials still use
KM (Austin & Fine 2017). Interval censoring: <2% handle it. Mediation: 98
RCTs/2 yrs, 96% Baron-Kenny. ML-HTE: 32 applied RCT studies to 2022.

### Economics / political science / tech experimentation
Top methods (Athey & Imbens 2017; J-PAL/DIME guides; Young 2019; McKenzie
2012; Kohavi-Tang-Xu 2020; Johari et al. 2022):
1. OLS / diff-in-means with HC-robust SE (HC1 default in econ)
2. Cluster-robust SE at the randomization unit
3. OLS with strata fixed effects + pre-specified baseline controls
4. Linear probability model for binary outcomes (dominant; logit is an
   appendix robustness check — Angrist & Pischke; Gomila 2021)
5. ANCOVA (lagged outcome) — the J-PAL/World Bank default post-McKenzie
6. Pre-specified subgroup interactions
7. 2SLS / LATE with assignment as instrument (very common: any RCT with
   take-up <100%)
8. Power/MDE (design stage)
9. Summary indices + Anderson FDR q-values / Romano-Wolf FWER
10. CUPED / pre-period regression adjustment (tech; = ANCOVA)
11. Lee (2009) bounds for attrition (common in dev/labor)
12. Winsorization / IHS / extensive-vs-intensive margin splits
13. Sequential / anytime-valid testing (mSPRT — Optimizely, Uber, Netflix)
14. Randomization inference (polisci default; econ robustness after Young)
15. Delta method for ratio metrics (tech); DiD inside RCTs (declining);
    wild cluster bootstrap for few clusters.
Quantile treatment effects: occasional (secondary "distributional effects"
figure; Firpo 2007; Bitler-Gelbach-Hoynes 2006). Tobit: rare, superseded by
level-OLS / Poisson-QMLE after Chen & Roth 2024. Poisson-QMLE for skewed
non-negative outcomes: rising. Ordered/multinomial logit: rare. Causal
forests: occasional econ, common tech. Switchbacks / saturation designs:
tech-/dev-specific.

### Psychology / education / criminology / marketing / HCI / sociology
Top methods (Blanca 2018; Counsell & Harlow 2017; Liddell & Kruschke 2018;
Spybrook 2020; WWC v5.0; Farrington & Welsh 2005; Marketing Letters 2024;
Syiem & Velloso 2026; ARS 2025):
1. Factorial / mixed / RM ANOVA with planned contrasts (21% of all
   procedures in psychology; ~half of JPSP articles; house style in
   marketing)
2. t-tests with Cohen's d (Hedges' g required by WWC)
3. OLS with treatment dummy + covariates, robust/clustered SE
4. HLM / mixed models for clustered RCTs (near-universal in IES CRTs)
5. Hayes PROCESS mediation with bootstrapped indirect effect (32.7% of
   regression analyses in psych; near-universal in consumer research)
6. Logistic regression / OR (criminology lingua franca; choice outcomes)
7. Moderation / moderated mediation / floodlight
8. χ² on proportions
9. Rank tests (Mann-Whitney, Kruskal-Wallis, Friedman; 71% of HCI omnibus
   tests) and Aligned Rank Transform ANOVA (HCI-specific)
10. ANCOVA pre-post
11. Conjoint AMCE via clustered OLS (polisci very common, sociology rising)
12. Multilevel OLS for factorial-survey vignettes (sociology)
13. Cox PH and NB counts (criminology)
14. SEM / path analysis with latent outcomes
15. CACE / Bloom adjustment (education secondary estimand)
Likert outcomes: 100% of JPSP/PS/JEP:G Likert analyses used metric models;
cumulative-link models ~10/527 tests at CHI. Bayes factors / TOST /
sequential: rare. Crossover / within-subject with period effects: common in
small pharma and psych.

---

## Part 4 — Gap analysis

Legend for "EDI status": **have** / **planned (plan file)** / **partial** /
**missing**. "Effort" is a rough implementation-size judgment given EDI's
existing machinery. Every row is now explicitly tagged:

- **Response type(s)** — which of EDI's six supported types (`continuous`,
  `incidence`, `proportion`, `count`, `survival`, `ordinal`) the method
  applies to, or "new type" if it needs a response type EDI doesn't have.
- **Y-shape** — **Univariate** (one scalar `y` per subject, within one of
  the six supported types) or **Multivariate** (a vector/repeated/
  ragged/multi-outcome `y` per subject, or a response family outside the
  six).

Per instruction, every **Multivariate** row and every row needing a **new
response type** is pulled out of the prioritized tiers below into
**Part 4D**, a non-prioritized deferred tier, regardless of how common the
method is in practice. Tiers 4A–4C therefore contain only univariate-`y`
methods within the six supported response types.

### 4A. Missing and very common — highest priority

| # | Method | Response type(s) | Y-shape | Fields & frequency | EDI status | Effort |
|---|---|---|---|---|---|---|
| 1 | **OLS with HC-robust (HC0/1/2/3) sandwich SE, non-interacted** (ATE / adjusted mean diff) | continuous (+ incidence via LPM) | Univariate | Econ, polisci: the single most common estimator; tech (z-test on means = HC0); sociology/criminology common | **partial** — `InferenceContinOLS` is homoskedastic; `InferenceContinLin` gives HC2 only with the full interaction | small |
| 2 | **Cluster-robust inference for cluster-randomized designs** (CR-SE sandwich; random-cluster-intercept GLMM; exchangeable GEE; wild cluster bootstrap for few clusters) | continuous, incidence, proportion, count, survival, ordinal (cross-cutting SE/variance layer) | Univariate | Medicine: GLMM 52% / GEE 16% of CRTs; education: near-universal HLM; econ/dev: cluster-robust SE is rule #2 | **partial** — `DesignFixedCluster` exists and randomization/bootstrap inference resample at the cluster level, but there is no model-based CR-SE and the GLMM/GEE components are KK-pair-specific | medium–large |
| 3 | **Instrumental-variable / LATE / CACE for noncompliance** (Wald/Bloom estimator = ITT ÷ compliance difference; 2SLS with covariates) | all six (cross-cutting; needs a treatment-received field) | Univariate | Econ: very common (any take-up <100%); education: standard NCEE secondary estimand (Schochet & Chiang); medicine: occasional in behavioral/surgical trials | **missing** — the design has no "treatment received" field | medium |
| 4 | **Treatment × covariate interaction / subgroup (moderation) estimands** (conditional ATE by subgroup; interaction contrast) | continuous, incidence, proportion, count, survival, ordinal (regression classes) | Univariate | Very common in every field (forest plots in medicine; PAP-registered subgroups in econ; moderation in psych/marketing; WWC moderators in education) | **missing** as an estimand — `model_formula` expands covariate interactions but the treatment coefficient is always the single main effect | medium |
| 5 | **Count/rate models with exposure (person-time) offset** (rate ratio per unit exposure) | count | Univariate | Medicine: NB with offset is the standard for exacerbation/relapse/hospitalization rates (>70% in respiratory, estimate); criminology place-based trials | **missing** — no `offset`/`exposure` in Poisson/NB/hurdle/ZI classes or kernels | small |
| 6 | **Standardized mean difference (Cohen's d / Hedges' g) with CI** (SMD) | continuous | Univariate | Psychology/education/criminology: reported in the majority of trials; required by WWC; the effect-size currency of meta-analysis | **missing** | small |

Notes on effort/implementation for each row are the same as before this
restructuring:

1. Add `se_type = c("classical","HC0","HC1","HC2","HC3")` to
   `InferenceContinOLS` (and `InferenceIncidRiskDiff`, the LPM). Cheap,
   high-visibility.
2. `full_glmm_for_weibull_frailty.md` and the longitudinal plan already
   generalize pair machinery to k-size clusters; a `ClusterRobust` SE
   component + `InferenceContinClusterGLMM`/`GEE` family would close this.
   Also needed: small-cluster corrections (CR2/CR3, Satterthwaite df —
   Kahan et al. found most few-cluster CRTs use none).
3. **What an encouragement design is and why it needs a second variable.**
   An encouragement design randomizes an *offer* (a voucher, an
   invitation, a nudge), but subjects decide whether to take it up. So
   there are two binary variables per subject:
   - `w` — what was randomly **assigned** (offer / no offer). EDI stores
     this.
   - `d` — what was actually **received** (took the treatment / didn't).
     EDI has no slot for this.

   With only `w`, you can estimate the **ITT** — the effect of being
   offered — which every existing EDI class already does. With `d` as
   well, you can additionally estimate the **CACE / LATE** — the effect of
   the treatment itself on the subjects who comply — via the Bloom/Wald
   estimator:

   ```
   CACE = ITT_on_y / ITT_on_d
        = (mean y | w=1 − mean y | w=0) / (mean d | w=1 − mean d | w=0)
   ```

   i.e. the ITT scaled up by the compliance-rate difference. With
   covariates it becomes 2SLS with `w` instrumenting `d`. This is very
   common in econ (any RCT with take-up < 100%) and the standard NCEE
   secondary estimand in education (Schochet & Chiang 2009).

   The item therefore splits across the two audits:
   - **Design side (`missing_design_classes_literature_audit.md`, #3):**
     a `Design$add_treatment_received(d)` / `d` vector — one stored
     column with asserts (`d ∈ {0,1}`; optionally one-sided
     noncompliance `d ≤ w`), carried through bootstrap / permutation
     replay exactly the way `y` is. Small.
   - **Inference side (this audit, #3):** `InferenceAllCACEWald`
     computing the ratio above with delta-method / bootstrap /
     randomization-based inference (the Bloom adjustment is trivial once
     compliance is recorded), plus a 2SLS variant on the regression
     classes (a small OLS extension). Medium.

   The design-side piece is a prerequisite for the inference-side piece,
   which is why the two rows cross-reference each other.
4. A `moderator =` argument on regression classes returning the
   interaction coefficient (and subgroup-specific effects) with the same
   Wald/bootstrap/randomization contracts. The Lin class already builds
   the interacted design matrix.
5. Add `exposure =` (log-offset column) to the count likelihood family and
   C++ kernels. Without it, EDI cannot analyze the most common
   count-endpoint trial design.
6. `InferenceContinStandardizedMeanDiff` (Hedges' g with small-sample
   correction, noncentral-t or bootstrap CI; cluster-adjusted g for CRTs).
   Pure estimand wrapper over existing machinery.

### 4B. Missing and common in at least one major field

| # | Method | Response type(s) | Y-shape | Fields & frequency | EDI status | Effort |
|---|---|---|---|---|---|---|
| 9 | **Competing risks** (cause-specific Cox; Fine-Gray subdistribution HR; cumulative-incidence difference at t) | survival | Univariate (single time-to-event `y` per subject, cause-coded) | Medicine: 31/40 top-journal TTE trials competing-risk-prone, 77% mishandled (Austin & Fine); Fine-Gray occasional in cardiology/nephrology/oncology | **missing** — survival response has a single event indicator | medium–large |
| 11 | **Win ratio / win odds / probability of superiority / Brunner-Munzel** (single-outcome form) (P(T>C) − P(C>T) or ratio; probabilistic index) | continuous, incidence, proportion, count, survival, ordinal | Univariate | Medicine: 68 win-ratio RCTs 2012–24, growing fast; DOOR in ID trials; Mann-Whitney parameter as ordinal estimand; HCI/psych rank tests report only p-values | **partial** — `InferenceOrdinalJonckheereTerpstraTest` gives Mann-Whitney stochastic superiority for ordinal only; Wilcoxon classes return Hodges-Lehmann shift, not the probability | small |
| 12 | **Mediation** (indirect effect, bootstrapped a·b; counterfactual NDE/NIE) | continuous, incidence, proportion, count, ordinal (primary `y` stays scalar; adds one mediator column) | Univariate | Psych: 32.7% of regression analyses; marketing: near-universal; medicine: occasional (98 RCTs/2 yrs, 96% Baron-Kenny); education/sociology occasional | **missing** — no mediator concept | medium–large |
| 13 | **Factorial (2×2, 2×k) designs with main effects and interaction** (factor main effects, interaction contrast) | continuous, incidence, proportion, count, survival, ordinal (multi-arm crossed factors) | Univariate | Psych/marketing: the modal design; econ: 27 top-5 factorial RCTs 2007–17 (Muralidharan et al.) | **partial / planned** — `multi_arm_designs.md` handles K arms, not crossed factors | medium |
| 14 | **Crossover / within-subject designs** (period + sequence effects, subject random effect) | continuous (typical; extendable) | Univariate | Medicine: common in small pharma/PK trials; psych: repeated-measures ANOVA is very common | **missing** — no period/sequence concept; KK pairs are the closest analog | medium |
| 15 | **Sequential / group-sequential / anytime-valid inference** (interim-look-valid tests and CIs) | continuous, incidence, proportion, count, survival, ordinal (cross-cutting monitoring layer) | Univariate | Medicine: 77% of CV trials with interims use OBF/Lan-DeMets; tech: mSPRT platform default; psych: rare | **planned** — `sequential_inference.md` (scoping only; may defer to 1.2) | large |
| 16 | **Missing-outcome handling**: Lee (2009)/Manski bounds; multiple imputation for outcomes; IPW for attrition (bounds on ATE under differential attrition; MAR-valid ATE) | continuous, incidence, proportion, count, survival, ordinal | Univariate | Econ/dev: Lee bounds common; medicine: MI 8% of trials, sensitivity 35%; education: MI common in IES work | **missing** — EDI imputes covariates but has no missing-outcome pathway | medium |
| 17 | **Mantel-Haenszel stratified OR / RD (true CMH)** (stratum-pooled OR/RD) | incidence | Univariate | Medicine/pharma: common in regulatory binary-outcome analyses; 10% of ordinal-outcome trials use CMH | **partial** — `InferenceIncidCMH` is a legacy blocked mean-difference with randomization SE, not the MH OR estimator | small |
| 18 | **Non-inferiority / equivalence (TOST) convenience** (one-sided test vs margin; equivalence interval) | continuous, incidence, proportion, count, survival, ordinal | Univariate | Medicine: NI trials are common (antibiotic, biosimilar); psych: TOST rare in practice | **partial** — every class has `compute_two_sided_pval(delta)` and CIs, so NI is derivable by hand | small |
| 19 | **Unconditional quantile treatment effect** (Q_τ(Y1) − Q_τ(Y0); Firpo 2007) | continuous (extendable to count/proportion) | Univariate | Econ: occasional (secondary distributional figure); tech: p50/p95 latency at Netflix/Google | **partial** — EDI has *conditional* quantile regression; the unconditional QTE is a different estimand | small |
| 20 | **Poisson-QMLE / Gamma-log GLM for skewed non-negative continuous outcomes** (proportional log-scale effect on the mean) | continuous | Univariate | Econ: rising fast after Chen & Roth 2024 (replacing log(1+y)); health economics: gamma GLM for costs | **partial** — `InferenceCountPoisson`/`RobustPoisson` are count-typed and reject continuous y | small |

Notes:

9. Needs an event-type code on the survival response (`dead ∈
   {0,1,2,…}`), then cause-specific Cox is a filter on the existing Cox
   kernel; Fine-Gray needs a weighted partial likelihood kernel; CIF
   difference via Aalen-Johansen. Not in any plan; the landscape report
   mentions recurrent events but not competing risks.
11. `InferenceAllWinOdds` / `InferenceAllProbSuperiority` (Brunner-Munzel
    variance, all six response types via pairwise comparisons with
    censoring rules for survival) is cheap and generalizes JT. (The
    *hierarchical multi-endpoint* win ratio is a different, multivariate
    method — see Part 4D.)
12. Requires a post-treatment mediator column on the design.
    Product-of-coefficients with EDI's bootstrap is straightforward;
    Imai-Keele-Tingley sensitivity analysis is a stretch. This is the
    single largest gap for psychology/marketing users.
13. Factorial = multi-arm with a structured contrast matrix; add a
    `factorial =` contrast layer on top of the multi-arm plan so main
    effects and the interaction come out as named estimands with FWER
    control.
14. Two-period AB/BA reduces to a paired analysis with a period term;
    could reuse the KK pair-difference machinery with a period covariate.
15. Already scoped. Given "very common" in two fields, consider not
    deferring.
16. Lee bounds are a trimming estimator over existing mean-diff classes
    (cheap). MI for outcomes needs a Rubin's-rules pooling layer over any
    inference class (moderate).
17. A proper `InferenceIncidMantelHaenszelOR` (Robins-Breslow-Greenland
    variance) and MH-RD (Sato / Greenland-Robins) over the existing block
    structure.
18. `compute_noninferiority_pval(margin, direction)` and
    `compute_equivalence_pval(bounds)` on the base `Inference` contract;
    document ITT-vs-PP population choice.
19. `InferenceAllQuantileDiff` (difference of sample quantiles with
    bootstrap/randomization CI; Harrell-Davis or Firpo-RIF variance).
    Cheap; complements the three (soon five) conditional QR families.
20. Allow continuous non-negative `y` in the robust-Poisson class (or a
    new `InferenceContinLogLinkQMLE`) and add a Gamma-log GLM.

### 4C. Missing but occasional/rare, or a poor fit for EDI's paradigm

| # | Method | Response type(s) | Y-shape | Fields & frequency | EDI status | Comment |
|---|---|---|---|---|---|---|
| 21 | Bayesian parametric primary analysis (priors on effect, posterior probability of benefit, Bayes factors, borrowing/hierarchical) | continuous, incidence, proportion, count, survival, ordinal | Univariate | Medicine ~1% of phase III (rising with platform trials; FDA 2025 draft guidance); tech vendors common; psych occasional (JASP) | **partial** — Bayesian bootstrap only; sequential plan mentions Bayesian monitoring | Large effort (Stan/JAGS or conjugate kernels). Worth a scoping report; the Bayesian bootstrap already gives posterior-like intervals. |
| 22 | ML-assisted covariate adjustment / HTE (TMLE, DML, causal forests, GATES/BLP) | continuous, incidence (typical) | Univariate | Medicine rare/emerging (32 RCT applications); econ occasional; tech common | **missing** | Poor fit for EDI's exact-inference philosophy and heavy dependency footprint; a re-analysis of 50 trials found ANCOVA with a few covariates matched ML (arXiv 2602.00434). Defer. |
| 24 | Aligned Rank Transform ANOVA; Kruskal-Wallis/Friedman for k groups | continuous, ordinal (k-arm) | Univariate | HCI very common; psych occasional | **missing** (k>2 needs multi-arm) | Multi-arm plan + a rank-based k-sample class would cover the omnibus; ART is HCI-only. |
| 26 | Switchback / saturation / interference designs | continuous, incidence, proportion, count, survival, ordinal (design-side, not response-type-specific) | Univariate | Tech common; dev-econ occasional | **missing** | Design-side; not an inference-class gap per se. |
| 29 | Random-effects multi-site meta-analysis of a single trial's sites | continuous, incidence, proportion, count, survival, ordinal | Univariate | Education (NCEE) and criminology multi-site programs common | **partial** — block structure exists; no site-heterogeneity estimand | Site random effect = cluster GLMM (#2) with site as cluster and treatment within site. |
| 30 | Ordered/multinomial logit for choice; ordinal models for Likert | ordinal (have) | Univariate | Practice: Likert treated as metric ~100% in psych; ordered logit rare in econ | **have** (ordinal family is richer than practice) | No gap; EDI is ahead here. (The choice/nominal piece is tracked separately in Part 2, not a gap-report action item.) |
| 31 | Tobit / censored continuous | continuous | Univariate | Econ rare (superseded); assay detection limits in medicine occasional | **planned** — `censored_continuous_response.md` | Already scoped. |
| 32 | Wilcoxon/Mann-Whitney as a *test* with HL shift | continuous, incidence, proportion, count, survival, ordinal | Univariate | Everywhere occasional–common | **have** | No gap; but see #11 for the probabilistic-index estimand. |

---

## Part 4D — Deferred (non-prioritized): multivariate `y`, or a response type outside EDI's current six

Per instruction, every method that needs a vector/repeated/multi-outcome
response, or a response family EDI does not currently support, is
collected here regardless of how common or high-effort it is elsewhere.
These are **not ranked** and carry no priority ordering — they wait on
their own response-type decisions (mostly already tracked as separate
plans in Part 2) rather than competing with the univariate items above.

| # | Method | Response type(s) | Y-shape | Fields & frequency | EDI status | Comment |
|---|---|---|---|---|---|---|
| 7 | Longitudinal / repeated measures (MMRM, mixed models, GEE) | **new** `longitudinal` (ragged `(subject, wave, y)`) | Multivariate (repeated per subject) | Medicine: very common (42% of CTU primaries); psych/education growth curves occasional | **planned** — `longitudinal_repeated_measures_response_type_report.md` (decision-gated) | The plan defers treatment×time and unstructured covariance, which is exactly the MMRM specification pharma uses — worth flagging to the plan owner even though it stays in this deferred tier by response-type. |
| 8 | Multiple-endpoint adjustment & summary indices (Holm/Bonferroni; Romano-Wolf FWER; Anderson FDR q-values; Kling-Liebman-Katz/Anderson index) | **new** (K endpoints per subject) | Multivariate | Econ: common since ~2015 (PAP culture); medicine: hierarchical testing in regulatory trials | **planned (partial)** — `multivariate_response_type_report.md` proposes Holm + Fisher/O'Brien global test | Extend the planned composite wrapper with Romano-Wolf, Anderson q-values, and the summary-index estimand once that response type is decided. |
| 10 | Recurrent events (Andersen-Gill; LWYY marginal rate; joint frailty) | survival-adjacent, but needs a counting-process response (multiple event times per subject) | Multivariate | Medicine: occasional, cardiology HF standard alongside NB; described as "the two most popular" recurrent-event methods (JACC 2023) | **missing** — landscape report rates it "hard", no plan | NB-with-offset (#5, univariate tier) covers the single-event-rate special case; true AG/LWYY needs a counting-process response, hence deferred here. |
| 23 | Conjoint AMCE / factorial vignettes / list experiments | **new** (many randomized profiles per respondent) | Multivariate | Polisci very common, sociology rising | **missing** | Different paradigm: many treatments within subject. Out of scope unless a "many treatments within subject" design/response family is added. |
| 25 | Delta-method ratio metrics (CTR, revenue/session) | **new** ("ratio-of-means"/composite response) | Univariate in form (one ratio scalar) but not one of the six supported types | Tech very common | **missing** | Deferred by the "not one of our six response types" clause even though the resulting statistic is a single number per arm, not per subject. |
| 27 | Multistate models; joint longitudinal-survival | **new** | Multivariate | Medicine rare/emerging | **missing** | Defer. |
| 28 | Cost-effectiveness (bivariate cost/QALY SUR, ICER bootstrap, CEAC) | **new** (bivariate cost + QALY) | Multivariate | UK HTA trials common; elsewhere rare | **missing** | Rides on the multivariate response plan; the bootstrap ICER is a thin wrapper once that lands. |

---

## Part 5 — Prioritized recommendations (univariate tier only)

Ordered by (breadth × frequency in practice) ÷ implementation effort.
Scope: only items from 4A/4B/4C (univariate `y`, one of EDI's six
supported response types) are ranked here — everything in Part 4D is
explicitly non-prioritized per instruction and is not ordered below.

1. **Exposure offset for count models** (#5) — small effort, unlocks the
   standard rate-ratio trial analysis; without it the count family cannot
   be used for the most common count-endpoint design in medicine.
2. **HC-robust SE option on OLS and LPM** (#1) — small effort, the econ /
   polisci default estimator.
3. **Standardized mean difference class** (#6) — small effort, the
   psych/education effect-size currency.
4. **Win odds / probability of superiority / Brunner-Munzel across all six
   response types** (#11) — small effort, generalizes existing JT test,
   catches the fastest-growing cardiology estimand in its single-outcome
   form.
5. **CACE / IV for noncompliance** (#3) — medium effort (needs
   treatment-received on the design), very common in econ and education.
6. **Treatment × covariate moderation estimand** (#4) — medium effort,
   very common everywhere.
7. **Cluster-robust SE component + random-cluster GLMM/GEE generalized
   from KK pairs** (#2) — medium–large, but the k-cluster generalization
   is already partly planned (`full_glmm_for_weibull_frailty.md`,
   longitudinal plan); this makes `DesignFixedCluster` analyzable the way
   practitioners expect.
8. **Mantel-Haenszel OR/RD** (#17), **NI/equivalence conveniences** (#18),
   **unconditional QTE** (#19), **Poisson-QMLE/Gamma for continuous
   non-negative** (#20) — each small; batch them.
9. **Competing risks** (#9) — medium–large; the most-mishandled survival
   situation in top journals and absent from every plan. Recommend a
   scoping report. (Still univariate `y` — one time-to-event per subject,
   cause-coded — so it stays in the prioritized tier despite the "large"
   effort.)
10. **Mediation** (#12) — medium–large; the largest gap for psychology /
    marketing users. Recommend a scoping report (mediator column +
    product-of-coefficients bootstrap first wave).
11. **Lee bounds / MI for outcomes** (#16) — medium; scope with the
    existing missingness machinery.
12. Reconsider deferring **sequential inference** (#15) to 1.2 given its
    "very common" status in two fields.
13. **Factorial contrasts** (#13) and **crossover** (#14) as extensions of
    the multi-arm plan.

Items 21–22, 24, 26, 29 are documented as out of scope/defer for reasons
other than response-type (see 4C); items 30–32 are "no gap, already have
it or already planned." **Items 7, 8, 10, 23, 25, 27, 28 (Part 4D) are
explicitly not part of this ranking** — they wait on their own
response-type/new-family decisions.

---

## Sources (selected)

Medicine: Jachno, Heritier & Wolfe 2019 (PMC6524252); Thompson et al.
*Trials* 2025 (PMC11694472); Selman et al. *Trials* 2024 (PMC10998402);
Ren et al. *J Clin Epidemiol* 2022; Fiero et al. *Trials* 2016
(PMC5013635); Nevins et al. *Clin Trials* 2024; Bell et al. 2014
(PMC4247714); Ooms et al. *Trials* 2025 (PMC12070558); Wang et al. 2023
(PMC10483862); Redfors/Pocock *Circulation* 2024; Austin & Fine *Stat Med*
2017; Karuppasamy et al. 2025 (PMC12482435); Vo et al. 2020; Ferreira et
al. 2020; FDA covariate-adjustment guidance 2023; ICH E9(R1).

Economics / polisci / tech: Athey & Imbens 2017 (arXiv 1607.00698); J-PAL
data-analysis guide; DIME handbook; McKenzie 2012 *JDE*; Bruhn & McKenzie
2009; Duflo-Glennerster-Kremer 2007; Young 2019 *QJE*; Muralidharan,
Romero & Wüthrich 2025 *REStat*; de Chaisemartin & Ramirez-Cuellar 2024;
MacKinnon & Webb 2018; Clarke, Romano & Wolf 2020; List, Shaikh & Xu 2019;
Lee 2009; Chen & Roth 2024; Gomila 2021; Firpo 2007; Bitler-Gelbach-Hoynes
2006; Deng et al. 2013 (CUPED); Johari et al. 2022; Kohavi, Tang & Xu 2020;
EGAP methods guides; Gerber & Green 2012.

Behavioral / social: Blanca et al. 2018 *Front Psychol*; Counsell & Harlow
2017; Cramer et al. (hidden multiplicity); Liddell & Kruschke 2018 *JESP*;
Bürkner & Vuorre 2019; Lakens 2014, 2017; WWC Handbook v5.0; Schochet &
Chiang 2009; Spybrook et al. 2020 *EEPA*; Farrington & Welsh 2005;
Weisburd 2016; Wilson 2022 *JQC*; Marketing Letters 2024; Hayes, Montoya &
Rockwood 2017; Syiem & Velloso 2026 (CHI Likert review); Vornhagen et al.
2020; Caine 2016; *Annual Review of Sociology* 2025; Wallander 2009;
Hainmueller, Hopkins & Yamamoto 2014; Blair, Coppock & Moor 2020.
