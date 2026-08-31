# Audit: Design Classes vs. Randomization Practice in the Literature

Generated 2026-08-26. Companion to
`missing_inference_classes_literature_audit.md`. Three-part audit: (1)
every concrete exported design class in `R/EDI/R/design_*.R`, (2) every new
design class or design-side capability proposed in `new_feature_plans/`
(and `new_research_ideas/`), (3) a literature survey of the
randomization/allocation designs practitioners of randomized experiments
actually use in medicine, economics, political science, tech A/B testing,
psychology, education, criminology, marketing, HCI and sociology — then the
gap between (3) and (1)+(2), with a frequency comment per missing design.

Frequency labels come from cited reviews where one exists (e.g.
"stratified permuted blocks in 47% of top-journal trials, Bruce et al.
2022"); otherwise they are judgments from guidance documents and are marked
"(estimate)". Reviews span different fields/journals/years (2005–2026).

Every gap row is tagged with two paradigm attributes so the tiering is
explicit:

- **Arms** — `2` (two-arm, EDI's current contract) or `K` (needs K>2 arms;
  the `multi_arm_designs.md` track).
- **Assignments/subject** — `1` (each subject receives exactly one
  assignment, EDI's current contract) or `many` (multi-period, crossover,
  within-subject, repeated/adaptive assignment).

Rows with `many` assignments per subject, or with arm structure beyond what
the planned multi-arm track covers, are pulled into **Part 4D**, a
non-prioritized deferred tier, regardless of how common they are —
mirroring the univariate/multivariate rule in the inference audit.

---

## Part 1 — What EDI has today (27 concrete exported design classes)

All classes: binary `w ∈ {0,1}`; all six response types accepted; `prob_T`
strictly in (0,1) unless noted; `design_formula`, missingness handling,
seed control, and randomization-draw replay for randomization inference
(except `DesignFixedOptimal` and the observational classes).

### Fixed-sample (13; all subjects known up front)

| Class | Mechanism | Covariates | Blocks/strata | Clusters | prob_T ≠ 0.5 |
|---|---|---|---|---|---|
| `DesignFixediBCRD` | complete randomization, fixed `n_T` | no | no | no | yes |
| `DesignFixedBernoulli` | iid coin flips | no | no | no | yes |
| `DesignFixedBlocking` | stratified complete randomization within strata (`randomizr::block_ra`; continuous strata quantile-binned) | strata only | yes | no | yes |
| `DesignFixedOptimalBlocks` | covariate-homogeneous blocks by anticlustering / MILP, then randomize within block (block size ≥ 2; covers matched quadruplets/small strata) | yes | yes (computed) | no | yes |
| `DesignFixedCluster` | cluster-level complete randomization (`randomizr::cluster_ra`) | cluster id | no | yes | yes |
| `DesignFixedBlockedCluster` | stratified cluster randomization (`block_and_cluster_ra`) | strata + cluster id | yes | yes | yes |
| `DesignFixedBinaryMatch` | optimal non-bipartite matched pairs (Mahalanobis), coin within pair | yes | pairs | no | **no** |
| `DesignFixedMatchingGreedyPairSwitching` | matched pairs + greedy pair-flip to minimize aggregate imbalance | yes | pairs | no | **no** |
| `DesignFixedGreedy` | greedy pairwise-swap search minimizing Mahalanobis / abs-sum-diff | yes | no | no | **no** |
| `DesignFixedGreedyDOptimal` | Fedorov-style exchange maximizing D / A / Bayesian information criteria | yes | no | no | yes |
| `DesignFixedOptimal` | deterministic single optimal allocation (MILP / annealing); no randomization draw | yes | no | no | yes |
| `DesignFixedRerandomization` | Morgan-Rubin rerandomization (Mahalanobis / abs-sum-diff threshold or top-quantile) | yes | no | no | yes |
| `DesignFixedFactorial` | balanced complete randomization across factorial cells — **currently hard-limited to exactly 2 cells** (stopgap until multi-arm lands) | no | no | no | no |

### Sequential one-by-one (11; subjects arrive and are assigned on arrival)

| Class | Mechanism | Covariates | Strata | prob_T ≠ 0.5 |
|---|---|---|---|---|
| `DesignSeqOneByOneBernoulli` | iid coin per arrival | no | no | yes |
| `DesignSeqOneByOneiBCRD` | random allocation rule (exact `n_T` at the end) | no | no | yes |
| `DesignSeqOneByOneEfron` | Efron biased coin toward under-represented arm | no | no | tie-coin only |
| `DesignSeqOneByOneUrn` | Wei UD(α, β) urn | no | no | no argument (1:1) |
| `DesignSeqOneByOneAtkinson` | Atkinson D_A-optimal biased coin | yes | no | fallback coin |
| `DesignSeqOneByOnePocockSimon` | Pocock-Simon minimization (`p_best` random element; `p_best = 1` = Taves) | categorical strata | marginal | tie-coin only |
| `DesignSeqOneByOneSPBR` | stratified permuted blocks, fixed block size | strata only | yes | yes (integer-count) |
| `DesignSeqOneByOneRandomBlockSize` | permuted blocks with random block size, optional strata | strata only | optional | yes (integer-count) |
| `DesignSeqOneByOneKK14` | Kapelner-Krieger matching-on-the-fly | yes | pairs | burn-in only |
| `DesignSeqOneByOneKK21` | KK14 with response-weighted distance | yes + responses | pairs | burn-in only |
| `DesignSeqOneByOneKK21stepwise` | KK21 with stepwise weights | yes + responses | pairs | burn-in only |

### Observational (3)

`ObservationalDesign` (user-supplied `w`; no randomization law),
`ObservationalDesignBlocks` (adds block vector for resampling),
`ObservationalDesignMatching` (pairs from subject order).

### Infrastructure

`define_design_class()` factory; component registry (`BlockingStructure`,
`ClusterStructure`, `MatchingStructure`, `BatchWPregeneration`,
`SequentialStrataBootstrap`); class registry with `timing_family` /
`randomization_family` / capability metadata; unexported
`DesignFixedCustom` / `DesignCustomSequential` bases for user-defined
designs (still binary `w`).

**What the family cannot express (verified absences):** K>2 arms (so no
true 2^k, fractional factorial, dose-ranging, or A/B/n); any multi-period
or multiple-assignment-per-subject structure (crossover, stepped-wedge,
switchback, N-of-1, SMART, micro-randomized, within-subject
counterbalancing); response-adaptive allocation (KK21 uses responses only
to weight the matching distance, not to shift allocation probabilities);
interim-stopping logic at the design layer; cluster-level versions of any
covariate-balancing design (matching, optimal blocks, rerandomization,
greedy, D-optimal) — the cluster classes only stratify on user-supplied
strata; unequal allocation in the matched-pair and greedy-swap designs
(hard `prob_T = 0.5`); sequential enrollment of clusters.

**Where EDI is ahead of practice:** model-based optimal and near-optimal
designs (D/A/Bayesian exchange, MILP-exact, greedy swap, matched-pair
greedy flip) — essentially unused in field practice (Kasy 2016,
Bertsimas-Johnson-Kallus, GSW appear in methods papers and a few tech
teams, not in published RCTs); formal Morgan-Rubin rerandomization with
rerandomization-aware inference (practice does informal re-draws and
rarely reports them — Bruhn & McKenzie 2009: 32% of experts had
re-randomized subjectively, 1 of 18 papers documented it); Atkinson
DA-optimal biased coin (rare in trials, Bruce 2022: 1 biased-coin trial in
330); matching-on-the-fly (novel to EDI); optimal anticlustered blocks
(covers McKenzie's matched-quadruplet recommendation directly); and the
whole two-arm classical sequential toolbox (Efron, Wei urn, Pocock-Simon,
SPBR, random block sizes) in one API with randomization-inference replay.

---

## Part 2 — What is already planned

| Plan | Proposed design classes / capabilities | Status |
|---|---|---|
| `design_seq_many_by_many.md` | Third timing family `DesignSeqManyByMany` + concrete `Bernoulli`, `CRD`, `Blocking`, `Rerandomization` (Zhou et al. 2018 cumulative objective), `Atkinson`; follow-ups: `PocockSimon`, block-level D_A kernel, multi-arm variants | **v1.1.0 approved** (TODO-15, Phase 5F); TODO-1 decision batch open |
| `multi_arm_designs.md` | K>2 arms: `K` / `prob_T_vec` on `Design`; Phase 1a randomizr-backed `Blocking`/`Cluster`/`OptimalBlocks`/`BlockedCluster`; then K-arm kernels for Bernoulli/iBCRD/Efron/Atkinson/Urn/PocockSimon/SPBR/RandomBlockSize/Rerandomization/Greedy/D-optimal; lift `DesignFixedFactorial`'s 2-cell stopgap; Phase 2 K-arm KK/matching (open research question) | **v1.1.0** (TODO-8, Phase 5D); 1a/6 done, rest open |
| `design_fixed_greedy_pair_switch_merge.md` | Merge `DesignFixedGreedy` + `DesignFixedGreedyDOptimal` → `DesignFixedGreedyPairSwitch` with **unconstrained `prob_T`** | **v1.1.0** (TODO-11); deprecation story undecided |
| `sequential_inference.md` | Design-side analysis ledger (`record_analysis_event()`), `interim = TRUE` bypass; `SequentialMonitor` orchestration (not a design class) | scoping (TODO-13) |
| `full_glmm_for_weibull_frailty.md → TODO-8` | `allow_k_wise_groups` opt-in on `DesignFixedBinaryMatch` (k-wise groups via hand-supplied `m`); a real k-way matching design class explicitly deferred | proposed, not yet indexed |
| `quantum_upgrade.md` | QUBO/annealer solver hook on `DesignFixedOptimal` / `OptimalBlocks`; `DesignFixedQuboSampled` (A2) explicitly unscheduled | decision-gated (TODO-9b) |
| `new_research_ideas/design_seq_many_by_many_greedy_pair_switch.md` | `DesignSeqManyByManyGreedyPairSwitch` | research idea |
| `new_research_ideas/quantum_greedy_design.md` | `DesignFixedGibbs` (Boltzmann-sampled allocation, β-interpolation between greedy and uniform) | research idea; gated on simulations |
| `new_research_ideas/paper_JSS_EDI_exposition/paper_JSS_EDI_exposition.md §3.7` | Chipman-Mayberry-Greevy rematching-on-the-fly as a new one-by-one class | candidate only |
| `finished_features/design_fixed_optimal.md`, `fix_design_hierarchy.md` | shipped 2026-08-17 (`DesignFixedOptimal`, factory, registry, components, D/A merge) | done |

Explicitly rejected: `DesignFixedOptimal` as a mode flag; annealer as a
backend swap for greedy classes; QUBO for k=2 matching; quantum for
sequential designs; `DesignSeqManyByMany` inheriting from one-by-one;
`factor` storage for `w`; native K-arm inference retrofit; a new k-way
matching design class (deferred to its own future plan); KK21 on
longitudinal responses.

---

## Part 3 — What practitioners actually use (condensed)

### Medicine / clinical trials
Anchor reviews: Bruce et al. 2022 (330 individually randomized top-journal
trials); Kahan & Morris 2012; UK trialist survey 2012; Ivers et al. 2012
(300 CRTs); Mills 2009 (crossover); Rogatko 2007 / 2020–22 phase I reviews;
RAR review 2025; MAMS registry review 2022.
1. Stratified permuted blocks (centre ± 1–2 factors, random block sizes,
   central IWRS) — 47% of top-journal trials; the single most used design
2. Permuted blocks without stratification — ~10%
3. Minimization / Pocock-Simon with random element — 15% (rising; 20–30%
   in UK public trials, <5% US industry; EMA "strongly discourages")
4. Simple randomization — 6% (rising; mostly large trials)
5. Crossover AB/BA (Latin square / Williams for ≥3 periods) — 22% of RCTs
   by count (Mills 2009), dominated by PK/bioequivalence
6. Cluster randomization (≈10% of RCTs): stratified 32% / pair-matched
   19% / covariate-constrained 2% (→ 5–15% today, estimate) / minimized 2%
   / unrestricted 44% of CRTs
7. Unequal allocation (2:1) overlaid on blocks — 10–15% (estimate)
8. Group-sequential interim-stopping overlay — 25–35% of phase III
9. 3+3 dose escalation — 74% of phase I oncology (CRM 5.5%, BOIN 2.7%)
10. 2×2 factorial — 2–4% of RCTs; fractional factorial <0.2% (MOST)
11. Stepped-wedge cluster — ~1% but fastest-growing cluster design
12. Everything else individually <1%: biased-coin/urn/big-stick (2 of 330
    trials), rerandomization (<0.5%, estimate), RAR (65 planned trials
    1985–2023, 83% Bayesian), platform/MAMS (83 master protocols to 2019;
    62 MAMS to 2021), SMART (80), MRT (~30–60), N-of-1 (~120), TwiCs (46),
    Zelen, preference designs (44), split-mouth.

### Economics / political science / tech
Anchor sources: Bruhn & McKenzie 2009; de Chaisemartin & Ramirez-Cuellar
2024; McKenzie 2025; Muralidharan-Romero-Wüthrich 2025; Kasy & Sautmann
2021; EGAP/J-PAL/DIME guides; Kohavi-Tang-Xu; Netflix/Uber/LinkedIn
engineering blogs.
1. Hash-based Bernoulli user-level A/B (tech) — universal
2. Stratified/blocked complete randomization — the field-experiment
   default (13/18 published dev-econ RCTs; 800+ registry trials; median 36
   strata on 1–4 variables)
3. Cluster randomization (villages/schools/households/precincts), usually
   stratified — a large minority-to-majority of dev-econ RCTs
4. Multi-arm (2+ treatments vs control) — the norm in dev econ and tech
5. Simple randomization of survey-experiment vignettes — modal polisci
   experiment
6. Encouragement designs (randomized offer + IV) — very common
7. Ramp-up / holdout (tech) — very common
8. Factorial / cross-cutting / MVT — ~25% of top-5 econ RCTs 2007–17
9. Conjoint fully randomized profiles (polisci) — very common
10. Phase-in / waitlist rollouts (dev econ) — common
11. Matched pairs / matched quadruplets — 56% of experts had used pairs
    (2009); now 6–20% of AEJ:Applied papers; practice shifted to
    quadruplets/small strata after dCR-C
12. Informal rerandomization (re-draw on balance check) — 32–46% of
    experts had done it; ~never reported; formal Morgan-Rubin occasional
Also: randomized saturation two-stage designs (occasional, growing);
switchback time-clusters (common at Uber/DoorDash/Lyft); graph-cluster
randomization (LinkedIn/Meta/Airbnb, occasional); geo matched-market with
rerandomization (Google/Meta, common in ad measurement); bandits (common as
a tech product feature; <1% of econ RCTs — Kasy-Sautmann, Caria et al.);
sequential covariate-adaptive minimization — **rare in econ**;
Gram-Schmidt Walk / optimal designs — rare, some tech uptake.

### Psychology / education / criminology / marketing / HCI / sociology
Anchor sources: Blanca et al. 2018; Caine 2016; Syiem & Velloso 2026;
Spybrook et al. 2020; Parker et al. 2021; WWC v5.0; Farrington & Welsh
2005/2006; Weisburd & Gill 2014; Tanious & Onghena 2021; Wallander 2009;
Auspurg & Hinz 2015; Sawtooth surveys.
1. Simple between-subjects randomization, 2–4 arms (Qualtrics randomizer;
   "evenly present elements" = crude balancing counter) — universal default
2. Between-subjects 2×2 factorial (psych, marketing) — very common
3. Within-subjects with counterbalanced order (Latin square) — dominant at
   CHI (~800 within-subjects CHI papers 2023–25; only 12% address order
   effects); cognitive psych
4. Mixed between × within (pretest–posttest control) — 36.6% of ANOVA uses
   in psychology, the single most frequent design
5. Two-level cluster RCT, schools/classrooms randomized, unblocked — modal
   IES efficacy design (37 of 65 NCER efficacy trials 2013–18)
6. Multisite / blocked-by-site cluster RCT — 28 of 65 NCER trials; UK
   school CRTs 80% restricted (stratified/minimized)
7. Fully randomized paired-profile conjoint (sociology, polisci)
8. Choice-based conjoint with D-efficient / orthogonal fractional-factorial
   choice sets (marketing; 96% of Sawtooth projects)
9. Waitlist-control RCT (clinical psych) — 60 anxiety trials in 5 years
10. Multiple-baseline / ABAB single-case designs (special education) —
    423 SCEDs in 2016–18 alone; only 22% randomized
11. Place-based block-randomized (hot spot) or pair-matched cluster
    experiments (criminology; geo-experiments in marketing)
12. Factorial survey with D-efficient vignette decks (sociology); SMART/MRT
    as the fast-growing tail
Psych lab studies essentially never go beyond simple/Bernoulli
randomization; blocking appears only in clinical trials. Solomon
four-group: extinct (10 usable studies ever).

---

## Part 4 — Gap analysis

Legend for "EDI status": **have** / **planned (plan file)** / **partial** /
**missing**. "Effort" is a rough implementation-size judgment given EDI's
existing machinery.

### 4A. Missing and very common — highest priority (2 arms, 1 assignment/subject)

| # | Design | Arms | Assign./subj. | Fields & frequency | EDI status | Effort |
|---|---|---|---|---|---|---|
| 1 | **Unequal allocation (`prob_T ≠ 0.5`) in matched-pair, greedy-swap and minimization designs** | 2 | 1 | Medicine: 2:1 in 10–15% of trials (estimate; Dumville 2006, Hey & Kimmelman 2014), common in industry phase II/III; econ: occasional | **partial** — `BinaryMatch`, `MatchingGreedyPairSwitching`, `Greedy` hard-error at `prob_T ≠ 0.5`; `Efron`/`Urn`/`PocockSimon`/`Atkinson` use `prob_T` only as a tie/fallback coin, so they cannot target 2:1 | small–medium |
| 2 | **Cluster-level covariate-balancing designs**: pair-matched clusters, optimal cluster blocks (matched quadruplets), covariate-constrained cluster randomization (Moulton 2004 / `cvcrand`), stratified-then-rerandomized geo/matched-market designs | 2 | 1 | Medicine: pair-matched 19% of CRTs, constrained 5–15% of few-cluster CRTs and standard in NIH Collaboratory pragmatic CRTs; education: UK school CRTs 80% restricted; dev econ: matched pairs/quadruplets of villages very common; tech: Google/Meta geo tests rerandomize paired DMAs | **missing** — `DesignFixedCluster`/`BlockedCluster` only stratify on user-supplied strata; every covariate-balancing design (`BinaryMatch`, `OptimalBlocks`, `Rerandomization`, `Greedy`, `GreedyDOptimal`, `Optimal`) is subject-level with no cluster support | medium |
| 3 | **Encouragement design support** (randomized offer; treatment-received recorded for ITT + LATE/CACE) | 2 | 1 | Econ: very common (any RCT with take-up <100%); education: standard NCEE secondary estimand; polisci GOTV; medicine: behavioral/surgical trials | **partial** — the randomization itself is any existing design; the missing piece is a design-side `treatment_received` / `d` field (cross-ref inference audit #3, CACE/IV) | small (design) + medium (inference) |
| 4 | **Randomized saturation / two-stage designs** (clusters assigned a saturation level, individuals randomized within cluster at that rate) | 2 at unit level (saturation levels at cluster level) | 1 | Dev econ: occasional and growing (Crépon et al. 2013; Baird et al. 2018; Egger et al. 2022; "increasingly common", arXiv 2607.04257); tech marketplaces: related cluster-saturation designs | **missing** — needs per-cluster `prob_T` and a two-level assignment law; the unit-level contrast is still two-arm | medium |

Notes:

1. The greedy merge plan (`design_fixed_greedy_pair_switch_merge.md`)
   already rederives the swap delta for general `prob_T`; extend the same
   rederivation to `MatchingGreedyPairSwitching` (unequal-size "pairs" =
   1:2 triplets, or keep pairs and randomize the residual) and add a
   target-ratio argument to Efron/Urn/Pocock-Simon/Atkinson (the
   literature's allocation-ratio-preserving biased coin, e.g. Kuznetsova &
   Tymofyeyev 2012). Note that for minimization the UK survey found
   unequal allocation only occasional, so Pocock-Simon can be last.
2. Cheapest path: generalize the `ClusterStructure` component so any
   fixed covariate-balancing design can run on cluster-level covariate
   summaries (means/sizes) and broadcast `w` to members — one
   `cluster_col =` argument on `BinaryMatch`, `OptimalBlocks`,
   `Rerandomization`, `Greedy`, `GreedyDOptimal`, `Optimal`. Constrained
   cluster randomization is exactly `Rerandomization` at cluster level.
   Cluster-level bootstrap/randomization replay already exists.
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
   - **Design side (this audit, #3):** a `Design$add_treatment_received(d)`
     / `d` vector — one stored column with asserts (`d ∈ {0,1}`;
     optionally one-sided noncompliance `d ≤ w`), carried through
     bootstrap / permutation replay exactly the way `y` is. Small.
   - **Inference side (`missing_inference_classes_literature_audit.md`,
     #3):** `InferenceAllCACEWald` computing the ratio above with
     delta-method / bootstrap / randomization-based inference, plus a
     2SLS variant on the regression classes. Medium.

   The design-side piece is a prerequisite for the inference-side piece,
   which is why the two rows cross-reference each other. The
   randomization mechanism itself needs no change — any existing design
   class can be an encouragement design once `d` is recorded.
4. `DesignFixedClusterSaturation(saturations = c(0, .25, .5, 1),
   cluster_col =)`: stage 1 assigns saturation to clusters (stratified CR
   over saturation levels), stage 2 Bernoulli/CR within cluster at that
   rate. Randomization replay is two nested draws. Direct-effect and
   spillover estimands (treated-in-treated-cluster vs. untreated-in-
   treated-cluster vs. pure control) are two-arm contrasts on subsets;
   the saturation-level contrasts are multi-arm-shaped and would ride on
   the multi-arm track.

### 4B. Missing and common in at least one field (2 arms, 1 assignment/subject)

| # | Design | Arms | Assign./subj. | Fields & frequency | EDI status | Effort |
|---|---|---|---|---|---|---|
| 5 | **Response-adaptive randomization** (two-arm Thompson sampling / Bayesian RAR with burn-in and allocation caps; doubly-adaptive biased coin; play-the-winner as a historical special case) | 2 | 1 | Medicine: rare (65 planned RAR trials 1985–2023, 88% with burn-in, 51% capped; FDA 2019 permits); econ: rare (~a dozen — Kasy & Sautmann 2021, Caria et al. 2024, DIME pilots); tech: common as a product feature (Optimizely/Adobe/VWO MAB), rarely for decision-quality experiments | **missing** — KK21 uses responses only to reweight the matching distance; no class shifts allocation probability on observed responses | medium (design) / hard (valid inference after RAR — randomization tests need response-dependent replay) |
| 6 | **Allocation-tolerance sequential rules**: big-stick, maximal procedure (Berger), Chen's biased coin, Zhao's block urn / step-forward (NIH StrokeNet) | 2 | 1 | Medicine: rare (2 of 330 top-journal trials; used inside emergency/stroke networks); everywhere else: rare | **missing** — Efron/Wei/iBCRD/permuted blocks exist; the tolerance-based family does not | small (one sequential class with a `rule =` switch) |
| 7 | **Fixed-sample permuted blocks with random block sizes within strata** (the CONSORT 8b default when the whole cohort is enrolled at once but allocation must be concealed in time order) | 2 | 1 | Medicine: the #1 design (47%), usually run sequentially — which EDI's `SPBR`/`RandomBlockSize` already cover; a fixed-`n` pregenerated list is what IWRS systems actually store | **partial** — `DesignFixedBlocking` does complete randomization within each stratum (one big block), not size-4/6 permuted blocks; the sequential classes do | small (pregenerate the sequential rule for known `n`) |
| 8 | **Graph-cluster / ego-network cluster randomization** (clusters derived from a network by community detection or ego-clusters) | 2 | 1 | Tech: occasional (LinkedIn, Meta, Airbnb); dev econ: village networks occasional | **partial** — `DesignFixedCluster` takes any user-supplied `cluster_col`, so the randomization works once clusters are computed; no in-package cluster construction | small (document) / out of scope (graph clustering) |
| 9 | **Gram-Schmidt Walk / Kallus-style balanced randomized designs with explicit balance–robustness trade-off** | 2 | 1 | Methods literature and a few tech teams; rare in published RCTs | **partial** — `Rerandomization`, `Greedy`, `GreedyDOptimal` occupy the same space; GSW's specific guarantee (worst-case variance bound) is not implemented; the `DesignFixedGibbs` research idea is the closest planned analog | medium |
| 10 | **Waitlist / phase-in / pipeline rollout as a first-class design** (randomized rollout order, analysis at a fixed calendar time) | 2 (per analysis time) / K waves | 1 | Dev econ: common (PROGRESA, deworming); clinical psych: waitlist control very common (60 anxiety trials/5 yrs) | **have** for the two-wave case (any two-arm design + a "control receives treatment later" convention is analysis-side); K-wave rollout order is multi-arm-shaped → rides on `multi_arm_designs.md` | none / planned |

Notes:

5. Two-arm Thompson sampling with a burn-in and an allocation cap is a
   ~100-line sequential class; the hard part is the inference contract
   (`draw_ws_according_to_design()` under RAR depends on responses, so
   randomization tests must re-simulate responses under the sharp null
   from the observed ones — feasible for Fisher sharp nulls, and the
   bootstrap/Bayesian-bootstrap paths need explicit review). Worth a
   scoping report given tech demand and the `sequential_inference.md`
   overlap.
6. `DesignSeqOneByOneTolerance(rule = c("big_stick", "maximal", "chen",
   "block_urn"), tolerance = )`. Cheap, completes the classical sequential
   family.
7. `DesignFixedPermutedBlocks(block_sizes =, strata_cols =)` = pregenerate
   `DesignSeqOneByOneRandomBlockSize` for known `n`. Mostly a convenience
   and documentation gap.
10. Document the two-wave waitlist mapping in the vignette; nothing to
    build.

### 4C. Considered; not a gap or out of scope for non-paradigm reasons

| # | Design | Arms | Assign./subj. | Fields & frequency | EDI status | Comment |
|---|---|---|---|---|---|---|
| 11 | Stratified / blocked complete randomization; multisite individually-randomized trials (block = site) | 2 | 1 | Very common everywhere | **have** (`DesignFixedBlocking`, `SPBR`, `RandomBlockSize`) | — |
| 12 | Matched pairs / matched quadruplets / small strata at subject level | 2 | 1 | Dev econ common; criminology advocated | **have** (`BinaryMatch`, `OptimalBlocks` with block size 4) | EDI is ahead: optimal anticlustered blocks directly implement McKenzie's quadruplet recommendation. |
| 13 | Minimization with/without random element; Taves | 2 | 1 | Medicine 15% | **have** (`PocockSimon`, `p_best`) | See #1 for unequal allocation. |
| 14 | Efron biased coin, Wei urn, Atkinson | 2 | 1 | Medicine rare (1/330) | **have** | EDI ahead of practice. |
| 15 | Rerandomization (Morgan-Rubin) at subject level | 2 | 1 | Informal: common; formal: occasional | **have** | EDI ahead of practice (formal thresholds + rerandomization-aware inference). |
| 16 | Simple / Bernoulli randomization incl. hash-based A/B, Qualtrics "evenly present" counter | 2 | 1 | Universal | **have** (`Bernoulli`, `iBCRD`, sequential `iBCRD` ≈ the counter) | Hash-based assignment is an implementation detail of Bernoulli. |
| 17 | Ramp-up / staged rollout / long-term holdout (time-varying `prob_T`) | 2 | 1 | Tech very common | **partial** — sequential Bernoulli with a fixed `prob_T`; no schedule | Out of scope: a `prob_T` schedule is a platform concern; randomization replay would need the schedule recorded. Document. |
| 18 | Group-sequential / interim-stopping overlay | 2 | 1 | Medicine 25–35% of phase III; tech common | **planned** (`sequential_inference.md`) | Design-side ledger is the only design change. |
| 19 | Central IWRS/IVRS allocation service | 2 | 1 | Medicine >90% (estimate) | n/a | EDI's sequential classes are the allocation *rule*; the service/concealment layer is out of scope. |
| 20 | Quasi-experimental (RD, ITS), Zelen single/double consent, patient-preference / partially randomized, TwiCs / cohort-multiple RCT | 2 | 1 | Rare (46 TwiCs; 44 preference trials; Zelen <0.5%) | **partial** — `ObservationalDesign` covers "assignment given", preference/TwiCs are consent structures on top of ordinary randomization | Out of scope; document that a preference arm is an `ObservationalDesign` and the randomized arm is any design. |
| 21 | Solomon four-group | 4 | 1 | Extinct (10 usable studies ever) | **missing** | Not worth building; K-arm track would cover it trivially. |

---

## Part 4D — Deferred (non-prioritized): multiple assignments per subject, or arm structure beyond the planned multi-arm track

Per the tiering rule, every design in which a subject receives more than
one assignment (multi-period, within-subject, adaptive-intervention,
repeated micro-randomization) or whose arm structure is not a set of
parallel arms is collected here regardless of frequency. These wait on
their own response-shape / timing-family decisions (a `longitudinal`
response type, a multi-period `w`, or the multi-arm track) rather than
competing with the two-arm single-assignment items above. **Not ranked.**

| # | Design | Arms | Assign./subj. | Fields & frequency | EDI status | Comment |
|---|---|---|---|---|---|---|
| 22 | **Crossover AB/BA; Latin square / Williams for ≥3 periods** | 2 (or K) | many (periods) | Medicine: 22% of RCTs by count (Mills 2009), the FDA default for bioequivalence; psych within-subject; marketplaces (Uber Latin squares) | **missing** | Needs multi-period `w` and a `longitudinal` response (both decision-gated). Two-period AB/BA reduces to a paired design with a period term — the KK pair machinery is the natural host once periods exist (cross-ref inference audit #14). |
| 23 | **Within-subject with counterbalanced condition order** (Latin square / full permutation of order) | K | many | HCI: dominant CHI design (~800 papers 2023–25); cognitive psych very common; marketing sensory | **missing** | Same substrate as #22; additionally needs K conditions. |
| 24 | **Stepped-wedge cluster** (clusters cross from control to treatment at randomized times) | 2 | many (periods) | Medicine: ~1% of RCTs, fastest-growing cluster design (84 published Nov 2018–Feb 2021); education/health services | **missing** | Needs cluster-period `w` and longitudinal response; analysis is GLMM with period effects (70% of SW trials). |
| 25 | **Switchback / time-cluster designs** | 2 | many (time windows) | Tech marketplaces: common (Uber, DoorDash, Lyft, Instacart); Bojinov-Simchi-Levi-Zhao 2023 | **missing** | Time is the cluster; needs a period axis. |
| 26 | **Multi-arm parallel (A/B/n), true 2^k and fractional factorial, dose-ranging arms** | K | 1 | Multi-arm: the norm in dev econ and tech; 2×2 factorial: 2–4% of medical RCTs, ~25% of top-5 econ RCTs, modal in psych/marketing; fractional: <0.2% (MOST) | **planned** (`multi_arm_designs.md`; `DesignFixedFactorial` stopgap lifts with it) | Listed here only because it is already owned by its own plan; it is single-assignment and would otherwise be tier 4A. Factorial contrast structure (main effects + interaction as named estimands) is flagged in the inference audit (#13). |
| 27 | **Platform / master protocol / MAMS / basket / umbrella** (arms added and dropped, shared control, often Bayesian RAR) | K, time-varying | 1 (but arms change over calendar time) | Medicine: 83 master protocols to 2019, 62 MAMS to 2021, high-profile (RECOVERY, REMAP-CAP, I-SPY 2), <1% of trials | **missing** | Needs multi-arm + interim logic + RAR (#5) + arm-set changes; far beyond current scope. |
| 28 | **SMART (sequential multiple-assignment)** | K per stage | many (re-randomization of non-responders) | Behavioral health: 80 SMARTs 2009–24; clinical psych occasional | **missing** | Adaptive-intervention design; needs stage structure and embedded-regime estimands. |
| 29 | **Micro-randomized trials (mHealth JITAI)** | 2 per decision point | many (hundreds) | Digital health: ~30–60 completed MRTs (estimate) | **missing** | Repeated within-person randomization; proximal-effect estimands. |
| 30 | **N-of-1 and single-case experimental designs** (ABAB, multiple baseline with randomized phase starts) | 2 | many | Special education: dominant (423 SCEDs 2016–18; WWC SCD standards); N-of-1 medicine ~120 trials ever; only 22% of SCEDs randomized | **missing** | Within-person time series; randomization tests over phase-start points are a natural EDI fit *if* a within-person timing family existed. |
| 31 | **Conjoint (fully randomized profiles), factorial vignette decks (D-efficient), choice-based conjoint (orthogonal fractional factorial), audit/correspondence within-employer paired résumés** | many attributes × levels | many (profiles per respondent) | Polisci/sociology conjoint: very common; marketing CBC: 96% of Sawtooth projects; audit studies common in labor/sociology | **missing** | Many randomized profiles per respondent with respondent-clustered inference — a different paradigm (cross-ref inference audit #23). |
| 32 | **Phase I dose-finding (3+3, CRM, BOIN)** | K doses, assigned by rule not randomization | 1 | Phase I oncology: 3+3 in 74%, model-assisted rising | **missing** | Not a randomized design; out of scope. |
| 33 | **Bandit / contextual-bandit personalization with K arms** | K | 1 (but allocation adapts) | Tech: common product feature | **missing** | Two-arm RAR is #5; K-arm bandits wait on the multi-arm track. |

---

## Part 5 — Prioritized recommendations (two-arm, single-assignment tier only)

Ordered by (breadth × frequency in practice) ÷ implementation effort.
Scope: only 4A/4B items are ranked; everything in 4D is explicitly
non-prioritized and waits on its own response-shape / timing-family /
multi-arm decision.

1. **Cluster-level covariate-balancing designs** (#2) — generalize
   `ClusterStructure` so `BinaryMatch`, `OptimalBlocks`, `Rerandomization`,
   `Greedy`, `GreedyDOptimal`, `Optimal` accept `cluster_col =` and operate
   on cluster-level covariate summaries. One change unlocks pair-matched
   CRTs (19%), covariate-constrained CRTs (the NIH Collaboratory standard),
   matched-quadruplet village designs, and geo matched-market tests.
   Medium effort; the highest-leverage design gap.
2. **Unequal allocation in matching / greedy / minimization designs**
   (#1) — small–medium; ride the greedy-merge plan's general-`prob_T`
   rederivation and add a target ratio to the sequential coins. 2:1 is
   10–15% of medical trials.
3. **Design-side `treatment_received` field for encouragement designs**
   (#3) — small on the design side; pairs with the inference audit's
   CACE/IV item (very common in econ/education).
4. **Randomized saturation two-stage design** (#4) — medium; occasional
   but growing in dev econ, and the two-level draw generalizes cleanly.
5. **Allocation-tolerance sequential family** (#6: big-stick, maximal,
   Chen, block urn) — small; completes the classical sequential toolbox.
6. **Fixed-sample permuted blocks with random block sizes** (#7) — small
   convenience wrapper over the existing sequential rule.
7. **Two-arm response-adaptive randomization** (#5) — medium design work,
   hard inference work; recommend a scoping report jointly with
   `sequential_inference.md` (interim looks and RAR share the
   response-dependent-replay problem).
8. **Gram-Schmidt Walk** (#9) — medium; only if the `DesignFixedGibbs`
   research idea doesn't already cover the balance–robustness axis.
9. Documentation-only: waitlist/phase-in mapping (#10), ramp-up/holdout
   (#17), graph-cluster inputs (#8), preference/TwiCs as observational +
   randomized arms (#20), IWRS as out of scope (#19).

Items 11–16, 18 are "have" or "planned"; 21 is not worth building. **Items
22–33 (Part 4D) are explicitly not part of this ranking.** The single
biggest *deferred* cluster is multi-period/within-subject structure
(#22–25, #28–30): crossover, within-subject counterbalancing, stepped-wedge,
switchback, SMART, MRT, N-of-1/SCED together account for the dominant
designs in HCI, special education, digital health, PK trials and
marketplace experimentation. They all need the same substrate — a
`longitudinal` response type plus a period axis on `w` — which is why the
`longitudinal_repeated_measures_response_type_report.md` decision has
design-side consequences well beyond repeated-measures inference.

---

## Sources (selected)

Medicine: Bruce et al. *BMC Med Res Methodol* 2022 (PMC9727841); Kahan &
Morris *BMJ* 2012; McPherson et al. UK trialist survey *Trials* 2012
(PMC3522058); Ivers et al. *Trials* 2012 (PMC3503622); stratified-CRT
survey *Trials* 2020 (PMC7672868); Mills et al. crossover *Trials* 2009;
McAlister 2003 / Cochrane Handbook ch. 23 (factorial); Dumville 2006; Hey
& Kimmelman 2014; Rogatko 2007 and phase I 2020–22 review (PMC11428115);
Hatfield 2016; RAR review *Trials* 2025 (PMC12460923); Park et al. master
protocols 2019 (PMC6751792); MAMS registry review 2022 (PMC8915371);
stepped-wedge reviews (PMC4538902, PMC12758014); SMART scoping 2025; TwiCs
scoping 2024; ICH E9; EMA CHMP baseline-covariates 2015; FDA adaptive
design 2019; regulatory randomization guidance review 2023; StrokeNet block
urn 2023; NIH Collaboratory constrained-randomization chapter.

Economics / polisci / tech: Bruhn & McKenzie *AEJ:Applied* 2009; de
Chaisemartin & Ramirez-Cuellar *AEJ:Applied* 2024; McKenzie *Fiscal
Studies* 2025; Bai 2022 / Bai et al. matched-pair cluster (arXiv
2211.14903); Muralidharan, Romero & Wüthrich *REStat* 2025; Morgan & Rubin
*AoS* 2012; rerandomization review (arXiv 2512.05290); Kasy & Sautmann
*Econometrica* 2021; Caria et al. *JEEA* 2024; Baird et al. *REStat* 2018;
Crépon et al. *QJE* 2013; saturation designs (arXiv 2607.04257); Gerber &
Green 2012; EGAP randomization module; Hainmueller, Hopkins & Yamamoto
2014; Bojinov, Simchi-Levi & Zhao *Mgmt Sci* 2023; Holtz et al. Airbnb
*Mgmt Sci* 2024; Google TBR / Meridian GeoX; Meta GeoLift; Netflix and
Thumbtack rerandomization posts; Johari et al. always-valid inference;
Kohavi, Tang & Xu 2020.

Behavioral / social: Blanca et al. *Front Psychol* 2018; Caine *CHI* 2016;
Syiem & Velloso *CHI EA* 2026; Spybrook, Zhang, Kelcey & Dong *EEPA* 2020;
Raudenbush, Martinez & Spybrook 2007; Bloom et al. 2017; Parker et al.
2021 (PMC8311976); WWC Handbook v5.0; Schochet 2016/2020; Farrington &
Welsh 2005, 2006; Weisburd & Gill *JQC* 2014; Sherman & Berk 1984;
Tanious & Onghena *BRM* 2021; Hammond & Gast 2010; Wallander 2009; Auspurg
& Hinz 2015; Bansak et al. 2021; Quillian et al. *PNAS* 2017; Sawtooth
method surveys; Vaver & Koehler 2011; Cuijpers et al. 2024 (waitlist);
McCambridge et al. 2011 (Solomon); Charness, Gneezy & Kuhn 2012.
