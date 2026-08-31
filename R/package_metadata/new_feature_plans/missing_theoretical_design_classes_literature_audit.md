# Audit: Theoretical Design Classes vs. the Methodological Literature

Generated 2026-08-27. Third companion to
`missing_inference_classes_literature_audit.md` and
`missing_design_classes_literature_audit.md`. Those two audited what
*practitioners use*; this one audits what the *methodological / theoretical*
design literature has proposed — designs that mostly do **not** appear in
applied RCTs but that a package positioning itself as the reference
implementation of experimental design (and as the home of the
Kapelner-Krieger / BRT / KAK lineage) would be expected to contain, compare
against, or cite. The canonical example is the Gram-Schmidt Walk design.

Three literature sweeps were run: (1) fixed-sample covariate-balancing
designs; (2) sequential / online covariate-adaptive and response-adaptive
rules, plus inference-validity theory under adaptive designs; (3)
decision-theoretic / Bayesian / allocation-ratio designs, interference /
temporal / marketplace designs, and classical optimal-DoE and restricted-
randomization theory.

**Verification caveat.** Two of the three sweeps exhausted the session's
web-search budget and wrote the remainder from background knowledge, and
the budget was fully spent before a follow-up verification pass could run.
Citations are adequate for prioritization, not for quoting in a paper
without a check. Where sweeps disagreed (e.g. the venue of Banerjee-
Chassang-Montero-Snowberg 2020 — *AER*, not *Econometrica*), the version
consistent with my own knowledge is used. Items that could be settled
locally (repo grep, cross-reference to already-verified plan files) have
been settled and are stated as facts; the few that could not are marked
"(not web-verified)" with the best available attribution rather than left
as bare flags. These are: the journal venue of ARM/PSR, the R-port status
of `GSWDesign`, and the CRAN status of `RARtrials`.

Every row is tagged with the same paradigm attributes used in the design
audit — **Arms** (`2` / `K`), **Assignments/subject** (`1` / `many`) —
plus **Timing** (`fixed` / `seq`), and the same tiering rule applies:
anything outside two-arm / one-assignment-per-subject (or beyond the
planned multi-arm track) is collected in a non-prioritized deferred tier.

---

## Part 1 — Where EDI already is the theory package

Before listing gaps, it is worth recording that EDI already implements
more of the theoretical design literature than any CRAN package I know
of, and that several of the sweeps' "important" designs are EDI's own:

| Theory | EDI class(es) |
|---|---|
| Greedy pairwise-switching "nearly random" designs (Krieger-Azriel-Kapelner, *Biometrika* 2019) | `DesignFixedGreedy`, `DesignFixedMatchingGreedyPairSwitching` |
| Balance–randomness tradeoff / harmonized designs (Kapelner-Krieger-Sklar-Shalit-Azriel, *Am. Stat.* 2021) | the `n_iter` / rerandomization-threshold interpolation across `Greedy`, `Rerandomization`, `Optimal` |
| Matching-on-the-fly (Kapelner-Krieger 2014) and outcome-weighted matching (KK21; Morrison-Owen 2025 calibration) | `DesignSeqOneByOneKK14/KK21/KK21stepwise` |
| Morgan-Rubin rerandomization (2012) with Mahalanobis or \|Σdiff\| threshold, cutoff or top-quantile | `DesignFixedRerandomization` |
| Optimal non-bipartite matching before randomization (Greevy et al. 2004; Lu et al. 2011) | `DesignFixedBinaryMatch` |
| Threshold / anticlustered optimal blocking (Higgins-Sävje-Sekhon 2016 in spirit; McKenzie's quadruplets) | `DesignFixedOptimalBlocks` |
| Bertsimas-Johnson-Kallus (2015) exact optimal allocation by MIP | `DesignFixedOptimal` (MILP / annealing) |
| Fedorov exchange for D-, A-, Bayesian D_B/A_B-optimality; D_s/A_s via `interest =` | `DesignFixedGreedyDOptimal` |
| c-optimality for the treatment coefficient (Elfving) | **have, unlabelled** — for `Y ~ w + X`, c-optimality with `c = e_w` is minimizing `Var(β̂_w) ∝ 1/SSR(w \| X)`, which at fixed `n_T` is exactly Mahalanobis-distance minimization of arm means; i.e. `Greedy(mahal_dist)` / `Optimal(mahal_dist)` / `interest = "treatment"`. Worth documenting. |
| Atkinson (1982) D_A-optimal biased coin; Efron; Wei urn; Pocock-Simon (incl. Taves via `p_best = 1`); permuted blocks | the sequential family |
| Banerjee-Chassang-Montero-Snowberg (*AER* 2020) "randomize uniformly over the sufficiently balanced set" | conceptually = rerandomization; nothing to build beyond a doc sentence |
| Design-replay randomization tests (Simon & Simon 2011) valid under every restricted / adaptive design | the `draw_ws_according_to_design()` contract on every class |

Planned (see design audit Part 2): many-by-many batch family incl.
sequential rerandomization (Zhou et al. 2018), multi-arm track, greedy
merge with general `prob_T`, QUBO/annealer hook, and the `DesignFixedGibbs`
Boltzmann-sampled research idea.

---

## Part 2 — Gap analysis by family

Legend: **have** / **partial** / **planned** / **missing**. "Theory value"
is a judgment of how central the design is in the methodological
literature (citations, whether it is the benchmark others compare to),
independent of applied usage. "Effort" is relative to EDI's existing
engines (greedy swap, MILP/annealer, rerandomization acceptance loop,
sequential coin framework, replay tests).

### 2A. Fixed-sample covariate-balancing designs (2 arms, 1 assignment, fixed)

| # | Design | Optimizes / guarantees | Inference theory | Software | EDI | Theory value | Effort |
|---|---|---|---|---|---|---|---|
| 1 | **Gram-Schmidt Walk** (Harshaw, Sävje, Spielman, Zhang, *JASA* 2024; arXiv 2019) | Random ±1 assignment from a discrepancy walk on `[√φ I ; √(1−φ) X/ξ]`; finite-sample worst-case MSE bound `≤ (1/n)·min_β{‖μ−Xβ‖²/(φn) + ξ²‖β‖²/((1−φ)n)}`; `Cov(w) ≼ φ⁻¹(…)`; `φ ∈ (0,1]` is an explicit balance–robustness dial (φ = 1 ⇒ Bernoulli) | finite-sample sub-Gaussian CIs; conservative variance estimator; ridge-adjusted estimator; randomization test valid by re-running the walk | `GSWDesign.jl` (authors' official Julia package); community Python re-implementations; no CRAN R package known (not web-verified) | **missing** | highest — the modern benchmark every balance design is compared to; the natural comparator for EDI's harmonized designs | medium (O(n²k) walk; pure C++) |
| 2 | **Kallus (2018, *JRSS-B*) a-priori balance / kernel-MMD minimax design** | worst-case conditional variance over a function class F; RKHS ball ⇒ `f(w) = w'Kw` (MMD between arms); linear F ⇒ Mahalanobis; "randomize over K near-optimal" MIP with per-unit propensity constraints | minimax bound; permutation over the retained set | author code (Gurobi/Julia) | **partial** (linear F = EDI's Mahalanobis swap/MILP) | high — unifies balance criteria by function class | small–medium (new `objective = "mmd"` with a kernel on the swap/annealer/MILP engines; propensity constraint is a MILP row) |
| 3 | **Cytrynbaum (2023/24) matched k-tuple "local randomization"** | matched k-tuples with `k₁` treated per tuple ⇒ rigorous theory for **unequal allocation** with matching; optimal among coarsening designs; representativeness for survey targets | asymptotic normality + variance estimator | author code | **missing** (EDI pairs are 1:1; `OptimalBlocks` is a heuristic with no k-tuple theory) | high (econometrics) | medium (k-way non-bipartite grouping — `full_glmm_for_weibull_frailty.md` already defers a k-way matching design; this is its theory home) |
| 4 | **Bai (2022, *AER*) pilot-index optimal pairs** + Bai-Romano-Shaikh (2022, *JASA*) variance | pair on estimated `E[Y(1)+Y(0)\|X]` from a pilot rather than raw X; asymptotically MSE-optimal among stratified designs | BRS adjusted pair variance; valid t-test | none | **partial** (pairing mechanics exist; pilot-index input and BRS variance not) | high (econometrics) | small (a `score =` argument on `BinaryMatch`; the Bai-Romano-Shaikh pair-variance estimator is **confirmed absent** — no reference in `R/EDI/R/` — so it is an inference-side addition alongside) |
| 5 | **Tabord-Meehan (2023, *REStud*) stratification trees** | pilot data ⇒ tree partition of X + within-stratum allocation maximizing asymptotic efficiency | asymptotic | author R | **missing** | medium–high | medium |
| 6 | **Zhu & Liu (2023, *Biometrics*) pair-switching rerandomization** | greedy pair switches *until* the Mahalanobis threshold is crossed, then stop (not to a local optimum) — samples the Morgan-Rubin acceptance region 3–23× faster while preserving MR theory | unbiased; FRT valid; = MR asymptotics | none | **partial** (EDI has both pieces; not the "swap-until-threshold" hybrid) | medium | small (an `accept_at_threshold` flag on `Greedy` / a `sampler = "pair_switch"` on `Rerandomization`) |
| 7 | **MCMC samplers of the rerandomization acceptance region** (BRAIN, arXiv 2312.17230; MH, arXiv 2602.07613) | uniform sampling of `{w : M(w) < a}` when `p_a` is tiny | = MR | `fastrerandomize` (R, GPU) | **missing** | medium | small–medium |
| 8 | **Kasy (2016, *Pol. Anal.*) GP-prior Bayes-optimal deterministic design** | posterior-MSE-optimal single allocation under a GP prior | Bayesian only | author code | **partial** (`DesignFixedOptimal` with D_B/A_B = the linear-basis case) | high (the "why randomize" debate) | small (kernel-implied covariate expansion as the `Optimal` objective) |
| 9 | **Entropy / max-probability-constrained optimal design** (BRT; Nordin & Schultzberg 2022 *JCI*; Kallus §6) | maximize balance subject to `H(π) ≥ h₀` or `P(w_i = 1) ∈ [p, 1−p]` for every unit across the retained set | FRT valid over the set; power ↔ set size | `GreedyExperimentalDesign` | **partial** (implicit via `n_iter` restarts / top-quantile) | high (EDI's own theory made first-class) | small–medium (a per-unit propensity constraint in the MILP; an explicit retained-set size `K` on `Rerandomization`) |
| 10 | **Finely stratified rerandomization** (arXiv 2407.03279) | pairs/strata first, then rerandomize within-stratum residual imbalance | MR asymptotics | none | **missing** (composable: `OptimalBlocks` + `Rerandomization`) | medium | small |

### 2B. Rerandomization criterion variants (2 arms, 1 assignment, fixed)

All of these keep EDI's `DesignFixedRerandomization` loop and change only
the acceptance criterion. The cleanest implementation is one
**generalized quadratic-form criterion** `w'Aw` with a user-supplied or
named `A` (arXiv 2403.12815 "unified framework for rerandomization using
quadratic forms" nests all of them):

| # | Variant | Criterion | Theory | EDI | Effort |
|---|---|---|---|---|---|
| 11 | Tiers of covariates (Morgan & Rubin, *Ann. Stat.* 2015) | sequential orthogonalized Mahalanobis thresholds per prioritized covariate group | MR variance reduction per tier | **missing** | small |
| 12 | Ridge rerandomization (Branson & Shao, *Biometrika* 2021) | `(X'X + λI)⁻¹` in place of `(X'X)⁻¹` for p ≈ n / collinear X | closed-form variance reduction | **missing** | trivial (a `lambda =` argument) |
| 13 | PCA rerandomization (Zhang, Yin, Rubin 2023) | Mahalanobis on top-q principal-component scores | MR | **missing** | trivial |
| 14 | Bayesian-criterion rerandomization (Liu, Han, Rubin, Deng, *JASA* 2025) | posterior-expected-loss quadratic form with `A` from a prior on covariate–outcome coefficients | MR-type | **missing** (but EDI's D_B/A_B priors are the same object) | small |
| 15 | Kernel-discrepancy / MMD rerandomization (arXiv 1901.08984) | accept iff MMD²(X_T, X_C) < a | worst-case RKHS bias | **missing** | small (shares the kernel with #2) |
| 16 | Energy-distance / Wasserstein rerandomization | distributional (all-moments) balance | thin | **missing** | small |
| 17 | p-value-based acceptance (Zhao & Ding, *J. Econometrics* 2024 "No star is good news") | accept iff all covariate balance-test p-values > α — unifies Mahalanobis / tiers / ridge | LDR-type asymptotics | **missing** | small |
| 18 | Min–max \|t\| / optimal rerandomization with explicit retained-set size (Johansson, Schultzberg & Rubin, *JRSS-B* 2021; Schultzberg & Johansson 2020) | keep the `K` best allocations on `max_j \|t_j\|`; choose `K` for target FRT power | exact FRT over the set; asymptotics | **partial** (top-quantile is this without the per-covariate criterion or the power-targeted `K`) | small |
| 19 | Diminishing-threshold / diverging-covariates rerandomization (Wang & Li, *Ann. Stat.* 2022) | `a_n → 0`, `k_n → ∞` with Berry-Esseen rates | theory on threshold choice | **partial** (mechanism unchanged; guidance not exposed) | doc only |
| 20 | Li-Ding-Rubin (*PNAS* 2018) truncated-Gaussian-mixture CI; Li & Ding (*JRSS-B* 2020) rerandomization + Lin adjustment | analysis-side | asymptotically valid narrower CIs | **check inference suite** — design exists; whether the LDR non-normal CI and the Li-Ding combined variance are implemented was not verified | small (inference) |

### 2C. Sequential covariate-adaptive rules (2 arms, 1 assignment, seq)

| # | Design | Targets / guarantee | Inference validity | Software | EDI | Theory value | Effort |
|---|---|---|---|---|---|---|---|
| 21 | **ARM / PSR — Adaptive Randomization via Mahalanobis distance; Pairwise Sequential Randomization** (Qin, Li, Ma, Hu — PSR: arXiv 1611.02802, 2016; ARM: *Statistica Sinica* 2024 to the best of my knowledge; journal venues not web-verified) | one-by-one (ARM) or pairwise (PSR) coin: assign the arm that lowers the running Mahalanobis distance with prob `q`; **`M_n = O_p(1)`** (bounded covariate imbalance — provably better than Pocock-Simon's `O(√n)` on continuous covariates); achieves the efficiency of rerandomization with `p_a → 0`; K arms and unequal ratios | naive t conservative; Ma-Qin-Li-Hu adjusted/bootstrap tests valid | `carat` (CRAN; Ma, Ye, Qin, Hu et al.) implements `HuHuCAR`, `PocSimMIN`, `StrBCD`, `StrPBR`, `DoptBCD`, `AdjBCD` and their inference; ARM/PSR themselves are not in it as far as I know | **missing** | highest among sequential — the direct theoretical rival of KK14 and of the planned batch rerandomization | small (one coin rule on the existing sequential framework) |
| 22 | **Online balancing walk** (Arbour, Dimmery, Mai, Rao, *ICML* 2022) | the online Gram-Schmidt walk: `P(z_{n+1}=1) = ½ − ⟨w_n, x_{n+1}⟩/(2c)` on the running covariate-difference vector; `‖w_n‖_∞ = O(√log(nd))` w.h.p.; worst-case MSE within a log factor of offline GSW; linear time; K arms; any `prob_T` | martingale coin ⇒ replay test valid; Harshaw-type conservative variance | authors' Python | **missing** | high (the ML-side online benchmark) | small |
| 23 | **Hu & Hu (2012, *Ann. Stat.*) unified overall + margin + stratum family** | coin on `ω_o D_n + Σ ω_m D_n(margin) + ω_s D_n(stratum)`; all three imbalances `O_p(1)` iff `ω_s > 0` (Pocock-Simon is `ω_s = 0`, strata `O(√n)`) | Ma-Hu-Zhang 2015 | `carat` (`HuHuCAR`) | **partial** (Pocock-Simon = one corner) | high — the design the CAR asymptotic theory is written for | trivial (add the stratum term + weights to `PocockSimon`) |
| 24 | **Tolerance / hard-cap rules**: big stick (Soares & Wu 1983), Chen's coin (1999), Berger maximal procedure (2003), Zhao-Weng block urn (2011), Ehrenfest urn (Chen 2000), adjustable biased coin ABCD (Baldi Antognini & Giovagnoli 2004) | `\|D_n\| ≤ b` a.s.; Berger = max entropy subject to the cap; ABCD nests Efron/Wei/big-stick with explicit stationary law | exact replay tests | `randomizeR` | **missing** (whole class) | medium | small (one class, `rule =` switch) — already item #6 in the design audit |
| 25 | **Smith (1984, *JRSS-B*) generalized biased coin** `p = N_0^ρ/(N_0^ρ + N_1^ρ)` | `Var(D_n/√n) = 1/(1+2ρ)`: the parametric bridge from CRD (ρ=0) through Wei to permuted blocks (ρ→∞) | CRD-like | `randomizeR` | **missing** | medium (pedagogical / benchmark) | trivial |
| 26 | **Kuznetsova & Tymofyeyev allocation-ratio-preserving designs** (2011/2012, *Stat. Med.*) | for unequal targets, most coins/minimization drift each unit's *unconditional* `P(w=1)` away from the target; brick-tunnel / ARP-minimization keep it exact — which matters for replay-test validity | replay | none | **missing** | medium — becomes relevant the moment EDI's sequential coins accept `prob_T ≠ 0.5` (design audit #1) | small–medium |
| 27 | Baldi Antognini & Zagoraiou (2011, *Biometrika*) covariate-adaptive D-optimal biased coin; Ma & Hu (2013) kernel-density minimization; continuous-covariate minimization (Ciolino 2011; Nishi & Takaichi) | balance on strata / covariate distributions / continuous means with `O_p(1)` (BA&Z) or simulation-only guarantees | — | none | **partial** (Atkinson covers continuous covariates via D_A) | medium | small–medium |
| 28 | Signorini et al. (1993) dynamic balanced randomization | tiered tolerances (study → stratum → margins) | replay | none | **missing** | low | small |
| 29 | Atkinson (2002) K-arm D_A coin; Atkinson & Biswas (2005) skewed/Bayesian D_A coin | K arms; response-utility-weighted D_A with bounded loss | — | none | **missing** (K-arm rides multi-arm; skewed = CARA, see 2D) | medium | small on top of existing Atkinson |
| 30 | Bertsimas, Korolko & Weinstein (2019, *Oper. Res.*) online MIO covariate-adaptive optimization | per-arrival MIO minimizing moment discrepancy with lookahead and a randomization constraint; finite-sample bounds | replay | none | **missing** | medium | medium |
| 31 | Chipman, Mayberry & Greevy, "Rematching on-the-fly: sequential matched randomization and a case for covariate-adjusted randomization," arXiv:2203.13797 (2022, v3 2023; no confirmed journal venue — citation verified in-repo on 2026-08-18, see `new_research_ideas/paper_JSS_EDI_exposition/paper_JSS_EDI_exposition.md`) | a rematching variant of KK matching-on-the-fly; already a candidate in the JSS plan §3.7 | — | none public | **candidate** | medium | small–medium (on top of KK14) |

### 2D. Response-adaptive and covariate-adjusted response-adaptive rules (2 arms, 1 assignment, seq)

EDI has none of these; KK21 uses responses only to reweight the matching
distance and never shifts the allocation probability. The class as a
whole is item #5 in the design audit; the individual designs below are
what a "two-arm RAR" class should contain, ordered by theoretical
standing.

| # | Design | Targets / guarantee | Inference | Software | Theory value | Effort |
|---|---|---|---|---|---|---|
| 32 | **DBCD** (Eisele 1994; Hu & Zhang, *Ann. Stat.* 2004) and **ERADE** (Hu, Zhang & He, *Ann. Stat.* 2009) | target any `ρ(θ)` (Neyman `σ_A/(σ_A+σ_B)`; RSIHR `√p_A/(√p_A+√p_B)`); SLLN/LIL/CLT for `(N_A/n, θ̂_n)`; ERADE attains the Hu-Rosenberger (2003) variance lower bound — the theoretically optimal RAR | Wald valid with inflated variance; replay test | `RARtrials` (CRAN, 2024, to the best of my knowledge — not web-verified); `randomizeR` covers RPW only | highest in RAR | small–medium |
| 33 | **Tempered Thompson / Bayesian adaptive randomization** (Thall & Wathen 2007, `c = n/2N`); **exploration sampling** (Kasy & Sautmann, *Econometrica* 2021: `p ∝ p_k(1−p_k)`, policy-regret optimal) | expected response / policy regret; `O(log T)` regret; no balance guarantee; allocation can hit extremes | sample means biased & non-normal ⇒ needs Hadad et al. (2021 *PNAS*) adaptively-weighted AIPW or Zhang-Janson-Murphy batched OLS; sharp-null replay test valid | `bandit`, `contextual`, `banditsCI` | high (dominant in tech and in the inference-after-adaptivity literature) | medium (design) / hard (valid inference contract) |
| 34 | **RPW urn** (Wei & Durham 1978), generalized Pólya urns (Bai & Hu 1999/2005), **drop-the-loser** (Ivanova 2003 — attains the allocation-variance lower bound among urns) | fewer failures; `N_A/n → ρ`; CLT iff `q_A + q_B < 3/2` | Wei et al. 1990; replay | `randomizeR` (RPW) | medium (historical; clean asymptotics) | small |
| 35 | **CARA** (Zhang, Hu, Cheung & Chan, *Ann. Stat.* 2007); reinforced DBCD / compound-optimal CARA (Baldi Antognini & Zagoraiou, *Ann. Stat.* 2012); Atkinson-Biswas skewed D_A; Villar & Rosenberger (2018) CARA forward-looking Gittins | covariate-specific target allocation `π(x, θ̂)`; balances covariates *and* skews allocation; full CLT for MLE and allocation proportions | model-based Wald valid under ZHCC conditions | none | high | medium |
| 36 | UCB / Gittins / controlled FLGI (Villar, Bowden & Wason, *Stat. Sci.* 2015); Bandyopadhyay-Biswas link-function RAR (2001) | regret / expected successes with control protection | severe power loss unless control protected | none | medium | small–medium |
| 37 | Cautionary theory to encode as diagnostics: Robertson et al. (*Stat. Sci.* 2023) "RAR: from myths to practical considerations"; Proschan & Evans (2020) time-trend confounding | — | — | — | — | doc |

### 2E. Decision-theoretic, allocation-ratio and Bayesian designs (2 arms, 1 assignment, fixed)

| # | Design | Content | EDI | Theory value | Effort |
|---|---|---|---|---|---|
| 38 | **Neyman allocation and its pilot-based variants**: Neyman (1934) `n_T/n_C = σ_T/σ_C`; Hahn-Hirano-Karlan (2011 *JBES*) stratum-specific propensities from a pilot; Cai & Rafi, "On the performance of the Neyman allocation with small pilots," *J. Econometrics* 2024 (arXiv 2206.04643) — regularized Neyman for small pilots; Blackwell-Pashley-Valentino batch-adaptive Neyman | choose `prob_T` (globally or per stratum) from pilot variances; semiparametric efficiency bound | **missing as a rule** (EDI accepts any `prob_T` on most fixed designs — the design audit's #1 covers the classes that don't — but has no `prob_T = "neyman"` / per-stratum allocation) | high (econometrics) | small (a helper that returns `prob_T` from a pilot; per-stratum `prob_T` on `Blocking`) |
| 39 | Minimax-regret allocation (Stoye 2009; Manski 2004; Kitagawa-Tetenov 2018) | for bounded two-arm outcomes 1:1 is MMR-optimal | **missing** — documentation value only | medium | doc |
| 40 | Utility / value-of-information Bayesian designs (Chaloner & Verdinelli 1995; Lindley) | expected posterior decision loss for a go/no-go decision | **missing** (D_B/A_B are the information-gain special case) | medium | medium |
| 41 | I-/V-optimality for CATE: `∫ Var(τ̂(x)) dF(x)` over the interacted model — an L-criterion `tr(L (X'X)⁻¹)` with `L` the covariate second-moment matrix on the interaction block; E-optimality (low value for two arms); G ≡ D (Kiefer-Wolfowitz) | heterogeneity-targeted design criterion nobody has written as an assignment rule; fits `interest =` | **missing** | medium (novel) | small |
| 42 | Space-filling / discrepancy / energy-distance assignment (star discrepancy, Székely-Rizzo energy) | nonparametric distributional balance objective | **missing** (≈ #2/#15/#16) | medium | small |

### 2F. Classical restricted randomization and DoE validity theory (2 arms, 1 assignment, fixed)

| # | Design / criterion | Content | EDI | Theory value | Effort |
|---|---|---|---|---|---|
| 43 | **Group-valid restricted randomization** (Grundy & Healy 1950; Yates; Bailey, *Biometrika* 1983; Bailey & Rowley 1987; Youden 1972) and **Hadamard randomization** (Bailey & Nelson 2003) | restrict to an *orbit of a permutation group* with second-order balance (every unit pair has equal probability of concurrence) ⇒ model-based ANOVA/OLS SEs remain exactly unbiased. Mahalanobis rerandomization is **not** group-valid (depends on X) — which is exactly why Li-Ding-Rubin needed new asymptotics and why OLS SEs are conservative under it. Hadamard randomization = a certified-valid, trend-robust restriction of permuted blocks | **missing** — both the Hadamard design and a **Grundy-Healy concurrence diagnostic** (report `max_{i,j} \| P(w_i = w_j) − const \|` over the design distribution for any EDI design) | high (finite-sample exactness criterion the rerandomization literature lacks; the classical ancestor of everything in 2A/2B) | small (diagnostic) / small–medium (Hadamard class) |
| 44 | Universal optimality of BIBDs / Youden squares (Kiefer); Pashley & Miratrix (2021 *JASA*) variance for mixed block sizes | for two treatments, blocks of size 2 = pairs; mixed/odd block sizes need the P&M variance | **have** (design); **check** the inference suite for P&M variances with heterogeneous block sizes | medium | small (inference) |
| 45 | Studentized FRT for the weak null (Wu & Ding 2021 *JASA*; Zhao & Ding 2021 *JRSS-B*, 2024 under rerandomization) | asymptotic weak-null validity of Fisher tests under restricted designs | **have** FRT; **check** that the studentized statistic is the default | high | doc / small |
| 46 | Higgins-Sävje-Sekhon (2016 *PNAS*) threshold-blocking approximation guarantee | `OptimalBlocks` is this in spirit | **have**; cite | — | doc |

### 2G. Inference-validity theory under adaptive designs (cross-cutting; inference side)

Not designs, but the theorems that determine which inference contract is
valid for which design — worth recording because they are what EDI's
replay-test architecture is implicitly relying on:

| Design class | Naive permutation test | Design-replay FRT (Simon & Simon 2011) | Unadjusted Wald | Covariate-adjusted Wald | Key theorem |
|---|---|---|---|---|---|
| CRD / Bernoulli | valid | valid | valid | valid | classical |
| Efron / Wei / Smith / tolerance rules | ≈ valid (asymptotically CRD) | valid | valid | valid | Wei 1978; Bugni-Canay-Shaikh 2018 ("strong balance") |
| Stratified blocks / Hu & Hu with `ω_s > 0` | valid under sharp null | valid | conservative | valid (saturated) | BCS 2018; Shao-Yu-Zhong 2010 |
| Pocock-Simon / Atkinson / ARM / PSR | conservative | valid | conservative (explicit R²-dependent size) | valid | Ma-Hu-Zhang 2015 *JASA*; Ma-Qin-Li-Hu 2020/22; Ye-Yi-Shao 2022/23 model-robust adjustment |
| Matched pairs (KK14) | valid within pairs | valid | conservative | valid | Bai-Romano-Shaikh 2022 |
| Rerandomization (fixed or sequential) | invalid | valid | conservative | non-normal limit (LDR 2018) | Li-Ding-Rubin 2018; Zhou et al. 2018 |
| RAR / DBCD / urns | invalid | valid (responses permuted appropriately) | valid, inflated variance | valid | Hu & Zhang 2004; Simon & Simon 2011 |
| Thompson / bandits | invalid | valid (sharp null replay) | **invalid** (biased, non-normal) | needs AW-AIPW (Hadad et al. 2021) / batched OLS (Zhang-Janson-Murphy 2020) | Nie et al. 2018; Shin-Ramdas-Rinaldo 2019 |

Implication: every design in 2A–2F can be added under EDI's existing
replay-test contract; only 2D's response-adaptive designs need a *new*
inference contract (adaptively-weighted AIPW or batched estimators), which
is why the design audit flagged RAR as "medium design / hard inference".

---

## Part 2H — Deferred (non-prioritized): outside two-arm / one-assignment, or beyond the planned multi-arm track

Catalogued for completeness; **not ranked**. Several are "MILP-adjacent":
their design step reduces to minimizing a quadratic form `w'Aw` and could
run on `DesignFixedOptimal`'s engine if a user supplied `A` — noted where
true.

| # | Design | Arms | Assign./subj. | Content | EDI | Note |
|---|---|---|---|---|---|---|
| 47 | 2^K factorial rerandomization (Branson, Dasgupta, Rubin, *AoAS* 2016); multi-arm / unequal-arm rerandomization; Dasgupta-Pillai-Rubin (2015) factorial potential outcomes; Zhao & Ding (2022) factorial regression | K | 1 | Mahalanobis on the stacked contrast vector | **missing** | rides `multi_arm_designs.md`; the natural fix for the factorial stopgap |
| 48 | Multi-arm Atkinson (2002), multi-arm ARM/PSR, K-arm online balancing walk, K-arm bandits / controlled FLGI | K | 1 | K-arm versions of 2C/2D rows | **missing** | rides multi-arm track |
| 49 | Graph cluster randomization (Ugander et al. 2013; Ugander & Yin 2023 randomized clustering); ego-clusters (Saint-Jacques 2019); exposure mappings (Aronow & Samii 2017) | 2 | 1 (but interference) | design step = cluster randomization with graph-derived clusters; the new part is exposure-probability computation for HT estimation | **partial** (`DesignFixedCluster` with user clusters) | deferred (interference estimands) |
| 50 | Bipartite experiments (Pouget-Abadie et al. 2019; Harshaw et al. *JASA* 2023) | 2 | 1 on diversion units | design step is `min_w w'Aw` on the diversion graph — **MILP-adjacent** | **missing** | deferred |
| 51 | Randomized saturation (Baird et al. 2018) / two-stage (Hudgens & Halloran 2008; Vazquez-Bare 2023) | 2 at unit level | 1 | two-level assignment law | **missing** | design audit #4 (prioritized there as a two-arm design); theory pointers here |
| 52 | Switchback optimal design (Bojinov-Simchi-Levi-Zhao, *Mgmt Sci* 2023; Hu & Wager 2022 geometric mixing); minimax temporal designs (Basse, Ding & Toulis, "Minimax designs for causal effects in temporal experiments with treatment habituation," *Biometrika* 110(1), 2023) | 2 | many (periods) | minimax block length under order-m carryover; exact Fisher tests | **missing** | deferred (temporal) |
| 53 | Staggered rollout optimal design (Xiong, Athey, Bayati, Imbens, *Mgmt Sci* 2024) | 2 | many | T-optimal adoption-fraction schedule under TWFE + carryover (convex program) | **missing** | deferred; adjacent to the many-by-many family |
| 54 | Synthetic design / synthetic controls for experimental design (Doudchenko et al. *PNAS* 2021; Abadie & Zhao 2021) | 2 | 1 | joint choice of treated set and weights to match pre-period outcomes — **MILP-adjacent** with pre-outcomes as covariates | **missing** | deferred but closest to EDI's paradigm of anything in this tier |
| 55 | Optimal crossover / Latin squares (Kunert 1983/84; Bailey & Kunert 2006); cluster-crossover; stepped-wedge optimal (Hussey & Hughes; Hemming) | 2/K | many | universal optimality under carryover | **missing** | deferred (repeated measures) |
| 56 | Two-sided marketplace designs (Johari, Li, Liskovich, Weintraub, *Mgmt Sci* 2022; Bajari et al. *Stat. Sci.* 2023 MRD); budget-split; interleaving | 2 | 1 (two populations) | bias–variance under matching | **missing** | out of scope |
| 57 | D-efficient conjoint / choice designs (Kuhfeld 1994; Huber & Zwerina 1996; de la Cuesta-Egami-Imai 2022) vs uniform (Hainmueller et al. 2014) | many attributes | many profiles | information-optimal attribute-level designs | **missing** | deferred (conjoint paradigm) |
| 58 | Orthogonal arrays / fractional factorials / supersaturated / response surface / Taguchi | K factors | 1 | classical multi-factor DoE | **missing** | deferred / out of scope (dose-finding, screening) |
| 59 | Sequential-multiple-assignment (SMART), micro-randomized, N-of-1 optimal designs | 2/K | many | adaptive-intervention and within-person designs | **missing** | deferred (design audit 4D) |

---

## Part 3 — Prioritized recommendations (two-arm, one-assignment tier only)

Ordered by theoretical importance ÷ effort, and grouped by how they land
in EDI's architecture. Everything in Part 2H is explicitly unranked.

### Tier 1 — new engines / classes with the highest citation standing

1. **Gram-Schmidt Walk design** (#1) — the missing benchmark. Medium
   effort (a discrepancy walk in C++), immediate payoff: EDI can then run
   the GSW-vs-harmonized-design comparison that the BRT paper invites, and
   the online version (#22) falls out of the same code.
2. **ARM / PSR** (#21) — bounded-Mahalanobis sequential coin; small
   effort; the head-to-head with KK14 is a paper in itself.
3. **Online balancing walk** (#22) — small effort once #1 exists.
4. **Kallus kernel-MMD objective** (#2) as `objective = "mmd"` on the
   swap / annealer / MILP engines, plus the **per-unit propensity
   constraint** (#9) on the MILP — makes the entropy floor first-class.
5. **DBCD / ERADE + tempered Thompson / exploration sampling** (#32, #33)
   as the two-arm RAR class family — pairs with the design audit's RAR
   item and `sequential_inference.md`; the inference contract
   (adaptively-weighted AIPW) is the hard part and needs its own scoping.

### Tier 2 — drop-in variants of existing engines (each small)

6. **Generalized quadratic-form rerandomization** `w'Aw` with named
   `A ∈ {mahalanobis, ridge(λ), pca(q), bayes(prior), kernel, energy}` and
   **tiers** (#11–#16) — one argument yields six published designs.
7. **p-value acceptance and min–max-\|t\| with explicit retained-set size
   `K`** (#17, #18) — makes the entropy-vs-power tradeoff a parameter.
8. **Pair-switching rerandomization sampler** (#6) and an MCMC sampler
   (#7) — make randomization tests under tight thresholds practical.
9. **Hu & Hu stratum term on Pocock-Simon** (#23), **Smith's coin**
   (#25), **tolerance-rule class** (#24), **ARP designs** (#26) — completes
   the classical sequential toolbox; ARP becomes necessary once sequential
   coins accept unequal `prob_T`.
10. **Neyman / per-stratum allocation helper** (#38) and **Bai
    pilot-index pairing + BRS variance** (#4).
11. **Cytrynbaum k-tuple matching** (#3) — the theory home for the k-way
    matching design `full_glmm_for_weibull_frailty.md` deferred.
12. **I-optimal CATE criterion** (#41) via `interest =` — small and
    novel.

### Tier 3 — classical validity theory (cheap, high explanatory value)

13. **Grundy-Healy concurrence diagnostic** on every design (#43) and a
    **Hadamard randomization** class — supplies the finite-sample
    exactness criterion that separates group-valid restrictions (blocks,
    Hadamard) from X-dependent ones (rerandomization, greedy), and
    explains *why* the latter need LDR-type asymptotics or replay tests.
14. Documentation: c-optimality ≡ Mahalanobis (Part 1); BCMS 2020 ≡
    rerandomization; minimax-regret ⇒ 1:1; studentized FRT default (#45);
    Pashley-Miratrix mixed-block variance check (#44); LDR truncated-
    Gaussian CI check (#20).

### Research-novelty notes (for `new_research_ideas/`)

- **Gibbs / Boltzmann design** (`quantum_greedy_design.md`): no paper
  proves the randomization-test and tilted-Gaussian asymptotics for
  `π(w) ∝ exp(−β f(w))`; it unifies rerandomization (hard threshold),
  BRT/entropy constraints (β ↔ entropy), and BCMS's ε-randomization.
  Genuinely open.
- **GSW vs. KAK-2019 vs. harmonized designs**: same objective family,
  different randomness guarantees (sub-Gaussian covariance bound vs.
  near-maximal entropy); no published comparison.
- **ARM/PSR vs. KK14**: both bound covariate imbalance sequentially with
  different mechanisms (coin vs. matching); no published comparison.
- **I-optimality for CATE as an assignment criterion** appears unwritten.

---

## Sources (selected; see verification caveat)

Fixed-sample: Harshaw, Sävje, Spielman & Zhang *JASA* 2024 (arXiv
1911.03071); Kallus *JRSS-B* 2018; Bertsimas, Johnson & Kallus *Oper. Res.*
2015; Kasy *Pol. Anal.* 2016; Banerjee, Chassang, Montero & Snowberg *AER*
2020; Morgan & Rubin *Ann. Stat.* 2012, 2015; Li, Ding & Rubin *PNAS* 2018;
Li & Ding *JRSS-B* 2020; Wang & Li *Ann. Stat.* 2022; Branson & Shao
*Biometrika* 2021; Zhang, Yin & Rubin 2023; Liu, Han, Rubin & Deng *JASA*
2025; arXiv 2403.12815; arXiv 1901.08984; arXiv 2407.03279; Zhao & Ding
*J. Econometrics* 2024; Johansson, Schultzberg & Rubin *JRSS-B* 2021;
Schultzberg & Johansson 2020; Nordin & Schultzberg *JCI* 2022; Zhu & Liu
*Biometrics* 2023 (arXiv 2103.13051); Bai *AER* 2022; Bai, Romano & Shaikh
*JASA* 2022; Cytrynbaum 2023/24; Tabord-Meehan *REStud* 2023; Greevy et al.
2004; Lu et al. 2011; Krieger, Azriel & Kapelner *Biometrika* 2019;
Kapelner, Krieger, Sklar, Shalit & Azriel *Am. Stat.* 2021; Higgins, Sävje
& Sekhon *PNAS* 2016.

Sequential / adaptive: Qin, Li, Ma & Hu (arXiv 1611.02802); Arbour,
Dimmery, Mai & Rao *ICML* 2022; Hu & Hu *Ann. Stat.* 2012; Ma, Hu & Zhang
*JASA* 2015; Shao, Yu & Zhong *Biometrika* 2010; Bugni, Canay & Shaikh
*JASA* 2018; Ye, Yi & Shao 2022/23; Smith *JRSS-B* 1984; Efron 1971; Wei
1978; Atkinson 1982, 2002; Atkinson & Biswas 2005/2014; Pocock & Simon
1975; Soares & Wu 1983; Chen 1999; Berger, Ivanova & Knoll 2003; Zhao &
Weng 2011; Baldi Antognini & Giovagnoli 2004, 2015; Baldi Antognini &
Zagoraiou 2011, 2012; Kuznetsova & Tymofyeyev 2011/12; Eisele 1994; Hu &
Zhang *Ann. Stat.* 2004; Hu, Zhang & He *Ann. Stat.* 2009; Hu & Rosenberger
2003, 2006; Zhang, Hu, Cheung & Chan *Ann. Stat.* 2007; Thall & Wathen 2007;
Kasy & Sautmann *Econometrica* 2021; Villar, Bowden & Wason *Stat. Sci.*
2015; Robertson et al. *Stat. Sci.* 2023; Simon & Simon *Biometrika* 2011;
Hadad et al. *PNAS* 2021; Zhang, Janson & Murphy *NeurIPS* 2020; Zhou,
Ernst, Morgan, Rubin & Yu *Biometrika* 2018; Bertsimas, Korolko & Weinstein
*Oper. Res.* 2019; Rosenberger & Sverdlov *Stat. Sci.* 2008; Rosenberger &
Lachin 2016.

Decision-theoretic / classical: Neyman 1934; Hahn, Hirano & Karlan *JBES*
2011; Stoye 2009; Manski 2004; Chaloner & Verdinelli *Stat. Sci.* 1995;
Elfving 1952; Pukelsheim 1993; Atkinson, Donev & Tobias 2007; Kiefer 1959,
1975; Grundy & Healy *JRSS-B* 1950; Youden 1972; Bailey *Biometrika* 1983;
Bailey & Rowley 1987; Bailey & Nelson 2003; Bailey 2008; Pashley &
Miratrix *JASA* 2021; Wu & Ding *JASA* 2021; Zhao & Ding *JRSS-B* 2021.

Deferred paradigms: Ugander et al. *KDD* 2013; Ugander & Yin *JCI* 2023;
Harshaw et al. *JASA* 2023 (bipartite); Baird et al. *REStat* 2018; Hudgens
& Halloran *JASA* 2008; Aronow & Samii *AoAS* 2017; Bojinov, Simchi-Levi &
Zhao *Mgmt Sci* 2023; Xiong, Athey, Bayati & Imbens *Mgmt Sci* 2024;
Doudchenko et al. *PNAS* 2021; Abadie & Zhao 2021; Johari et al. *Mgmt Sci*
2022; Branson, Dasgupta & Rubin *AoAS* 2016; Dasgupta, Pillai & Rubin
*JRSS-B* 2015; Hainmueller, Hopkins & Yamamoto 2014.
