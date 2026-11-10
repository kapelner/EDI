# Streaming (Incremental) Estimation, Separate from Inference

> **Depends on:** `sequential_inference.md` (shares one state object with the
> `SequentialMonitor` and the analysis ledger); the 1.1.0 observational split
> (`release_v1_1_0.md → TODO-158`, `SeqOneByOneObservationalDesign`). Targeted
> at `release_v2_0_0.md` (user decision 2026-10-25). (Global ordering: see
> `_master.md`.)

Generated: 2026-10-25

## Scope

A feasibility and design plan, not an implementation spec. Question: when
1000 subjects have arrived and been fitted, and 1000 more arrive, can EDI
update the fit using the first batch's retained state instead of refitting
all 2000 rows from scratch, and can the algorithms for that be collected in
one place across every inference class?

## 0. Architecture decision (owner, 2026-10-25)

Streaming is a **fast estimation layer separate from the `Inference*`
classes**, not a mode of them. It is built for speed: no randomization,
bootstrap or p-value machinery, no R6 inference object per update, and
minimal allocation on the hot path. It has two paths:

- **Estimate-only path:** updates the coefficient / treatment-effect
  estimate from a new batch (or a single subject) and returns nothing else.
  This is the fastest path and must not pay for variance bookkeeping.
- **Estimate + stderr path:** updates the same estimate and also maintains
  whatever extra state a valid asymptotic standard error needs (for
  example the information matrix, or a sandwich meat term), and returns the
  SE with it. Anything that cannot give a valid SE from retained state
  refuses this path with a clear message instead of returning a stale or
  approximate one silently.

Consequences for the rest of this plan:

- A streaming estimator is a small stateful object (state in, batch in,
  state out), keyed by model family, with its own registry. It is not
  registered as an inference class and is not counted in the inference-class
  tally.
- An `Inference*` class may consume a streaming estimator's state to
  produce its asymptotic result, but streaming never depends on an
  `Inference*` class existing for the model.
- The estimate-only and estimate+stderr paths are separate entry points, not
  a flag on one function, so the fast path has no branch or allocation for
  the SE state. Each model family declares which paths it supports.
- Speed is a first-class requirement: each estimator needs a benchmark
  against the batch refit (the same rows) at several n and batch sizes, and
  hot loops belong in C++ (the targeted-compile rule in `CLAUDE.md`
  applies).

## 1. Findings that shape the plan

- **No finite sufficient statistic for most models.** Logistic regression
  has none, so an exact streaming MLE does not exist. The best general
  option is a warm start (begin Newton/IRLS at the previous coefficients),
  which cuts iterations but still touches every row.
- **Exact streaming exists for a small family:** OLS/WLS (retain XᵀX, Xᵀy),
  mean difference, Poisson and exponential (counts and total time), and
  possibly Cox via risk-set increments (caveats to be worked out).
- **The cost in EDI is usually not the point fit.** Randomization and
  bootstrap inference re-fit across thousands of draws, and the null
  distribution changes when new subjects arrive, so old draws cannot be
  reused. Streaming the point estimate speeds up a step that is already
  cheap.
- **Adaptive designs break naive pooling.** For KK matching and other
  response- or covariate-adaptive allocation, assignment depends on earlier
  data. Whether batches can be pooled is a property of the design, so the
  design must carry the flag.

## 2. Capability tiers

Each streaming estimator (model family) declares one tier per path
(estimate-only, estimate+stderr) in the streaming registry, in the style of
the existing `supports_*` flags. A family can be `exact` for the estimate
and `none` for the SE:

- `exact`: a finite sufficient statistic; the streamed result equals the
  batch fit to machine precision.
- `warm_start`: the same estimator as the batch fit, initialized from the
  previous fit; same answer to optimizer tolerance.
- `none`: refuses, with a clear message. Most model families start here
  on the estimate+stderr path, and that is the honest default.

## 3. Contract

1. **Equivalence test per family and path:** a streamed fit over batches
   equals the batch fit on all rows, for the estimate and, on the
   estimate+stderr path, for the SE, with a tolerance set by the tier (D2
   rule: numerical equivalence, not bit-for-bit; integers exact). The
   estimate-only path must also be shown not to allocate or compute SE
   state.
2. **Inference scope:** streaming covers the point estimate (estimate-only
   path) and the asymptotic SE (estimate+stderr path) only. Randomization
   and bootstrap p-values and CIs are out of scope: they are recomputed by
   the `Inference*` classes after new data arrives, and the streaming API
   never returns one, stale or otherwise.
3. **Design coupling:** streaming pairs with the sequential designs and with
   `SeqOneByOneObservationalDesign`. Pooling across batches is permitted
   only when the design declares it valid.
4. **State:** retained state per class must be small, mergeable across
   parallel workers, independent of thread count (seed per draw index, never
   per thread; see `release_v1_0_5.md → TODO-95`), and serializable in a
   versioned layout so the `libedi_core` backend in `release_v4_0_0.md` can
   adopt it unchanged.

## 4. Literature searches to do (added 2026-10-25, user note)

Section 1's claim that logistic regression "has no finite sufficient
statistic" is true for the exact MLE, but the user expects streaming hacks
to exist for logistic regression and other non-exponential-family and
non-canonical-link models. Section 1 should be treated as unverified until
these searches are done. The leads below come from memory, not from a
search; every name and reference is to be verified, and none should be
cited in docs before it is.

- **Online updating for GLMs:** cumulative estimating equations,
  one-step / meta-analytic updating of GLM and Cox estimates as batches
  arrive, and their asymptotic equivalence to the full-data estimator
  (search: "online updating estimating equations big data GLM",
  "renewable estimation streaming data", "incremental one-step estimator
  GLM").
- **Recursive and Kalman-type GLM fitting:** sequential Fisher scoring,
  recursive estimation for generalized linear models (search: "recursive
  GLM estimation Kalman Fahrmeir", "sequential Fisher scoring").
- **Stochastic approximation:** online Newton / stochastic Newton,
  averaged SGD (Polyak-Ruppert) with valid standard errors (search:
  "averaged stochastic gradient inference logistic regression standard
  errors", "online Newton step logistic regression").
- **Bayesian streaming:** assumed density filtering, Laplace-based and
  variational updating, Pólya-Gamma and other augmentation for logistic
  models (search: "assumed density filtering logistic regression",
  "streaming variational Bayes GLM").
- **Divide and conquer / one-shot averaging:** combining batch estimates
  with exact or near-exact equivalence (search: "divide and conquer GLM
  one-shot estimator", "meta-analysis of GLM batches likelihood
  combination").
- **Quadratic-approximation summaries:** retain the batch's score and
  information at the batch optimum and combine as a quadratic surrogate
  (search: "surrogate likelihood", "communication-efficient surrogate
  likelihood").
- **Beyond logistic:** the same questions for negative binomial, ordinal
  (cumulative link, stereotype), Weibull / AFT, Cox partial likelihood,
  quantile regression, beta regression, and the mixed-effects (GLMM)
  classes. Record per model whether an exact, approximate-with-known-error,
  or warm-start-only method exists.
- **Variance after streaming:** which methods give a valid asymptotic SE
  (sandwich or information) from the retained state, and which give point
  estimates only. This decides the tier in section 2.

For each hit, record in this file: the method, the model class it covers,
whether it is exact or approximate, the error bound if approximate, the
retained state size, and whether a reference implementation exists.
Candidate methods that are only approximate need a measured error against
the batch fit (D2 numerical-equivalence rule) before any class is marked
anything above `warm_start`.

## 5. Open decisions

- Public API shape for the separate layer: R6 objects vs. plain state lists
  plus functions (the latter is likely faster and easier to serialize), and
  the names of the two entry points.
- Batch size 1 (true per-subject streaming) vs. batches only; the hot-path
  cost differs a lot.
- One shared state object with `SequentialMonitor`, or separate objects with
  a common interface.
- Whether Cox risk-set streaming is exact enough to list as `exact`.
- Whether warm starts ship earlier as a standalone speedup (not required).
- Which classes get `exact` first; proposed order: OLS/WLS, mean difference,
  Poisson, exponential.
