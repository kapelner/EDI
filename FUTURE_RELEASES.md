# EDI Future Releases

A reader-friendly roadmap of what is planned for each upcoming release.
Each bullet summarizes one planned feature in at most a paragraph; the
authoritative scope, dependency ordering, and work breakdowns live in
`R/package_metadata/future_release_plans/` (one index file per release)
and the per-feature plans in `R/package_metadata/new_feature_plans/`.
Within each release, items that gate or feed other items come first;
the rest are grouped by theme. Plans are commitments of intent, not
promises — decision-gated items are marked as such.

---

## v1.1.0 — Inference Quality and CPU Performance

### Decisions and prerequisites

- **Phase 0 decision batch** — a single sitting that settles every gated
  design question for the 1.x line: the `estimate_type` API shape,
  penalized-fitting (Firth/L1/L2) inference semantics, the bias- and
  test-correction family, the response-type yes/nos (nominal, rank-choice,
  semi-continuous, multivariate, compositional, longitudinal), and the
  GPU/quantum backend story. No code; everything below that depends on a
  decision cites it.
- **Diagnostics chain** — optimizer diagnostics (free diagnostics,
  hardening, a `SolverDiagnostics` component that Firth requires), then the
  public diagnostics API. Strictly ordered; a prerequisite for the
  corrections track.

### Corrections and higher-order inference

- **Corrections track** — the small-sample likelihood toolbox, in
  dependency order: expanded `estimate_type` values; Cox–Snell and
  Cordeiro–McCullagh bias corrections (one project, shared `X'WX` helper);
  the higher-order test-correction batch (Cordeiro–Ferrari score
  correction as the anchor, then Lemonte gradient correction, then
  Bartlett LR correction, sharing one cumulant machinery); Firth penalties
  plus L1/L2 penalized paths; median bias correction; modified profile
  likelihood; and bootstrap-calibrated LR if its difficulty tier is
  approved.

### New estimators and estimands

- **KK one-stage Beta-regression estimator** — a joint-likelihood
  matched-pairs + reservoir estimator for proportion responses, prototyped
  against a glmmTMB-reuse path before the native Gauss–Hermite backend
  ships.
- **Count quantile regression** — `InferenceCountQuantileRegr` and its KK
  variants via Machado & Santos Silva (2005) jittering with B-averaged
  point estimates.
- **Count exposure offset** — `exposure =` on every count class and
  kernel, unlocking standard rate-ratio trial analyses.
- **Heteroskedasticity-robust standard errors** — `se_type = HC0..HC3` on
  OLS and risk-difference classes, with the sandwich helper extracted from
  the Lin class for reuse.
- **Small estimand additions** — Hedges' g, win odds / Brunner–Munzel,
  Mantel–Haenszel OR/RD, non-inferiority/equivalence conveniences,
  unconditional QTE, and a log-link QMLE path for non-negative continuous
  responses.
- **NegBin mixture marginal estimands** — extend
  `set_estimand("marginal_*")` to the zero-inflated and hurdle NegBin
  classes, with the rederived truncated-NegBin mean formula the Poisson
  shortcut does not cover.

### Ordinal, incidence, and count fixes

- **Ordinal Bayesian-bootstrap completions** — native weighted refits for
  the ordinal KK GEE, stereotype-logit, and adjacent-category-logit
  classes (replacing surrogates), each enabled only after draw-level
  parity tests.
- **Ordinal model-coefficient randomization CIs** — estimand-scale CI
  inversion for the ordinal regression classes, alongside the existing
  randomization p-values.
- **Incidence randomization CIs** — per-estimand-scale Zhang exact
  intervals, removing the temporary incidence CI disable.
- **Negative-binomial dispersion reparameterization** — replace the
  unbounded `log_theta` coordinate with an attainable Poisson-boundary
  parameterization across NegBin, ZINB, and hurdle-NegBin.
- **Reusable-bootstrap worker for zero-one-inflated Beta** — the one class
  (of 51 audited) missing the warmed-worker fast path; bit-identical
  jackknife required.

### InferenceSuite

- **Wilkinson r-out-of-k combined evidence** — a descriptive
  `vote_fraction` ("how many procedures agree") now, and a formal
  order-statistic test gated on whether its resampling-based null
  calibration is worth the cost; complements the existing Cauchy
  combination test, which answers only "does at least one detect a
  signal."

### Performance and correctness (CPU)

- **Randomization CI affine-shift reuse** — revive the never-populated
  `t0s_rand` fast path: for statistics linear in `y` with `w` in the
  design (mean diff, OLS, Lin), the null distribution at any shift δ is
  the δ = 0 distribution plus δ, exactly — so one distribution serves the
  entire CI search instead of ~20–35. Expected 20–30× on randomization
  CIs for those classes.
- **Wire the unused OLS randomization kernel** — a complete, exported C++
  batch kernel for the OLS null distribution has no caller; OLS currently
  runs an R-level per-replicate worker loop (~100–200 µs of overhead
  around a ~5 µs solve). Wiring it in is 20–50× on the distribution and
  multiplicative with the item above; eight other dead kernel exports get
  wired or deleted in the same pass.
- **Guard the unguarded information-matrix inverses** — five `with_var`
  kernels (NegBin, ZINB, ZAP ×2, Beta) invert the information matrix with
  no invertibility check, so a near-singular design yields a finite,
  wildly wrong standard error silently; they get the same
  `isInvertible()` guard their Cox/ordinal/ZOIB siblings already have,
  bit-for-bit on all invertible fits.
- **Performance profiling and upgrades lane** — the systematic
  measurement program: benchmark noise floor and regression gate,
  compiler optimization-report sweep, strided-access and linear-algebra
  audits, BLAS backend visibility.
- **More SIMD optimization** — implements what the profiling lane's
  diagnostics find: `__restrict` sweep, a confirmed fast-math subset in
  `configure`, aligned copies, branch-free comparisons, `-fopenmp-simd`.
- **Fixed-size Eigen specializations for small p** — compile-time-`p`
  dispatch for the per-iteration `p×p` algebra; gated on a microbenchmark
  showing a ≥10 % whole-fit win before any kernel is touched.
- **LTO re-evaluation** — `-fno-lto` is a measured-negative default;
  re-measure under the current toolchain, write down the flip rule, and
  add re-measurement triggers. A decision document, not necessarily code.
- **Memory-layout audit** — find the `n` at which column-major `X` under
  row-wise IRLS access actually starts to cost (predicted ≳10⁴, beyond
  the designed-experiment regime), and record the kernel-author policy.

### Testing and release

- **Full test-coverage triage** — from 64.8 % line coverage into the high
  90s: a tracked gap registry, the 31 zero-coverage files first, then
  weighted opportunity, then a CI coverage floor.
- **Release mechanics** — the standard checklist; the `edi_kernels`
  Python wheel ships from the same commit family.

---

## v1.2.0 — Performance, Kernels, and Engines

- **Quantile-regression C++ kernel** — LP solver → weighted variant →
  standard errors → R integration → parity suite.
- **Ordinal GEE C++ kernel** — the native estimating-equations kernel for
  the ordinal GEE classes.
- **Robust-regression performance** — profile-first optimization of the
  robust regression paths (measurement before SIMD).
- **Cold starts** — the documented cold-start audit and its follow-ups
  across fit families.
- **Greedy engine merge** — unify the greedy design-search engines
  (deprecation shims, not deletions); its `pair_mode` finding decides how
  1.3.0 handles matched pairs under unequal allocation.
- **OLS randomization kernel FWL rewrite** — inside the kernel wired in
  v1.1.0: hoist the Cholesky and residualized `y` once; each replicate
  becomes a masked sum, one small triangular solve, and an O(p²)
  denominator. 5–10× on the kernel; depends on the v1.1.0 wiring.
- **Sequential KK14 incremental covariance** — stop recomputing the
  covariance of all previous subjects from scratch at every arrival
  (O(n²p²) per run); a Welford running scatter matrix and monotone rank
  tracking make it O(p²) per subject, ~5–10× on sequential-design runs,
  with KK21 sharing the benefit.
- **Architecture-specific CPU and memory engines** — AArch64/Apple/
  Graviton detection and dispatch, Intel AMX capability checks and GEMM
  thresholds, NUMA/huge-pages memory tuning; shared detection/dispatch
  logic, benchmark evidence required before any default changes.

---

## v1.3.0 — Design Extensions from Practice

- **Unequal allocation** — `prob_T ≠ 0.5` on matched and greedy designs,
  `target_ratio` on sequential coins, a `neyman_prob_T()` helper, and
  per-stratum allocation; the route depends on 1.2.0's greedy-merge
  `pair_mode` finding (allocation-ratio-preserving coin rules follow in
  2.0.0).
- **Cluster-level covariate-balancing designs** — `cluster_col =` on every
  fixed balancing design (constrained cluster randomization, pair-matched
  clusters, matched quadruplets) plus `DesignFixedClusterSaturation`.
- **Sequential many-by-many design family** — `DesignSeqManyByMany` with
  Bernoulli / CRD / Blocking / Rerandomization (Zhou et al. 2018) /
  Atkinson members: batches of subjects arriving over time, a new timing
  family between fully-fixed and one-by-one.
- **Registry and capability metadata sweep** — `supports("cluster")`, the
  `prob_T` capability, the new `timing_family`, and the design-side
  vignette update.

---

## v1.4.0 — Response and Data Extensions

### Survival track (ordered)

- **Survival plumbing sweep** — the hard `dead → uncensored` rename (R,
  C++, Python; the only 1.x-era break) done in the same pass as
  competing-risks `event_type` storage, over the 31 `Surv()` sites;
  bit-for-bit golden tests for every existing survival class.
- **Competing risks** — cause-specific Cox and log-rank, CIF/Gray/RMTL,
  and Fine–Gray (via `cmprsk`, if the dependency is accepted); the
  counting-process kernel may trail into 2.0.0. Decision-gated.
- **Cure-fraction (mixture-cure) survival inference** — a standalone
  inference class on the existing survival type. Decision-gated.
- **Weibull-frailty k-strata** — the full GLMM generalization of the
  Weibull frailty model beyond two strata.
- **Interval-censored second wave** — semiparametric additions, if its
  Phase 0 decision is yes.
- **Survival quantile regression** — a custom self-consistent EM estimator
  for general interval-censored quantile regression plus KK variants, with
  three recorded open risks to close by test.

### Other response and data extensions

- **Censoring track** — censored continuous responses, censored count
  responses, and the Beta-regression-scale duplication cleanup; then
  semi-continuous responses if decided yes.
- **Encouragement designs / CACE** — `treatment_received` plumbing and
  complier-average causal effect inference.
- **Treatment–covariate moderation** — moderation analysis on the
  existing classes.
- **Missing outcomes** — principled handling of missing responses beyond
  the current NA-filtering.

### InferenceSuite summaries

- **Model-averaged estimate/CI** — a reportable model-averaged point
  estimate and CI across applicable models (Buckland/Burnham/Augustin
  variance, Akaike or inverse-variance weights), complementing the
  existence-style combined tests with an actual number.
- **Multiplicity-adjusted results table** — Holm (always valid) and
  Benjamini–Hochberg (gated on a dependence calibration check) applied to
  `results_table`'s rows, answering "which specific rows survive
  correction."
- **Selective (post-selection) inference, pilot** — PoSI/data-carving
  p-values and CIs valid conditional on having picked the best of k
  models, scoped to one pilot class (OLS) to price the approach before
  deciding on a broader rollout versus 2.0.0's sample-splitting sibling.

### Kernel performance batch (all exact unless noted)

- **Wilcoxon–HL kernel hoisting** — sort once instead of per replicate,
  per-thread buffers, and an early-stopping + warm-seeded bisection for
  the HL median; bit-identical, ~3–4× on Wilcoxon randomization
  distributions.
- **Ridit kernel level slots** — precompute the level structure so the
  default control-referenced ridit stops rebuilding its map per replicate;
  bit-identical, ~8–10×.
- **KK signed-rank rank hoisting** — at δ = 0 the absolute pair
  differences are permutation-invariant (only signs flip); hoist their
  ranks as the reservoir already does; bit-identical, ~4–5× on the pair
  component.
- **Rerandomization objective scoring** — replace a scalar O(r·n·p)
  accumulation with one GEMM and whiten the Mahalanobis form once;
  5–15×, tolerance-equal with a documented tie-breaking caveat.
- **Small kernel hoists batch** — greedy-search Gram-matrix trick, cached
  ordinal level lookups, counting-sort ordering of Cox bootstrap draws,
  and one shared cached Gauss–Hermite rule.

### Scoping

- **Sequential-inference scoping** — the analysis plan for
  anytime-valid/sequential inference, implemented in 2.0.0.

---

## v2.0.0 — Multi-Arm, New Response Shapes, and Backends

### Decisions and substrate

- **Decision batch** — every gated 2.0.0 track: the K-arm KK research
  question, each response-shape decision, GPU/quantum backends.
- **Longitudinal response type** — first, because it is the substrate for
  cluster GLMM/GEE and multi-period designs; then **multivariate**,
  **compositional**, and **rank/choice** response types in that order
  (nominal only if its recorded "no" recommendation is overturned).

### Major tracks

- **Multi-arm designs** — K-arm designs and inference on the existing
  factory.
- **Sequential inference and response-adaptive randomization** —
  implement the 1.4.0 scoping output, then two-arm RAR on top of it.
- **Cluster-robust GLMM/GEE inference** — after the longitudinal
  extraction. Decision-gated.
- **Mediation analysis** — after 1.4.0's `treatment_received` plumbing.
  Decision-gated.
- **Theoretical-design backlog** — classical sequential-coin completions
  (with the allocation-ratio-preserving rules), rerandomization criterion
  variants, optimal-design objective extensions, and the Gram–Schmidt
  walk / online balancing family with its two simulation studies.
- **Causal forest and Bayesian tree inference** — an HTE estimand and
  capability contract, a randomized-design forest path, then design-aware
  resampling modes and BART/BCF posterior adapters.

### Model-selection honesty

- **Sample-splitting / data-carving model selection** — pick the winning
  model on a selection half, test it on a confirmation half at full alpha;
  needs real `Design`-level splitting (thorny for matching-on-the-fly
  designs), which is why it is 2.0.0 scope; data carving gated on the
  measured power cost.
- **E-values / safe testing** — a validity framework whose evidence
  combination (simple averaging) stays valid under adaptive inclusion of
  more models, unlike any fixed-weight p-value combination; staged from a
  likelihood-ratio pilot subset.

### Backends and bindings

- **Compute backends** — the GPU dispatch architecture first, the quantum
  QUBO-export hook second (see the README's "Why EDI targets the CPU"
  section for why both are optional accelerators for specific workloads,
  not the fitting path), then an optional NPU graph/runtime adapter.
- **Shared C++ inference backend** — a stable ABI with a dual-backend
  compatibility window, the substrate for bindings beyond R and Python.
- **Additional language bindings** — only after the shared backend's ABI,
  release, and ownership decisions are complete.

### Breaking changes

- **Deletions and migrations** — the deprecated greedy classes are
  removed, and every accumulated 1.x → 2.0.0 contract break ships with a
  documented deprecation path and a migration guide.
