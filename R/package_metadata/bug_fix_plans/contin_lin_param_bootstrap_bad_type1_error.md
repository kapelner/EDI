# Fix: `InferenceContinLin` Parametric-Bootstrap / Likelihood-Ratio Methods — Inflated Type-I Error, Design-Dependent

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-15` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-37`, bug-fix/feature split). Found via the original
> `stale_worker_cache_resampling.md` bug hunt's `bad_type1_error` audit
> hit on `InferenceContinLin`; originally hypothesized to be the same
> stale-worker-cache mechanism as that plan's primary bug, but confirmed
> 2026-09-23 to be a **separate, unrelated, still-unfixed** mechanism —
> `InferenceContinLin`'s `rand`-family methods (fixed by that plan, part of
> its confirmed 7-class list) are NOT the methods flagged here; these three
> are a parametric-bootstrap/likelihood-ratio-simulation path that never
> routes through the reused-worker machinery that plan's fix touched.

## The bug, per the original audit

`R/package_tests/audit_comprehensive_results.R`'s `bad_type1_error` check
(rejection rate at `beta_T=0`, alpha=0.05, differing from nominal by >4 SEs
of Binomial(n, 0.05)) flagged `InferenceContinLin`
(`R/EDI/R/inference_continuous_lin.R`) on THREE methods simultaneously:
- `compute_lik_ratio_bootstrap_two_sided_pval` — z=19.4
- `compute_param_bootstrap_pval` — z=18.8
- `compute_lik_ratio_bartlett_approx_two_sided_pval` — z=16.4

## Confirmed by direct query of historical `comprehensive_tests` results

Filtered `R/package_tests/comprehensive_tests_results_nc_1_continuous.csv`
(845k rows) to `beta_T=0`, `status="ok"`:

**1. Isolated to `InferenceContinLin` — NOT shared machinery.** The sibling
class `InferenceContinOLS` uses the *identical* generic
`ParametricLikelihoodBootstrap`/`get_likelihood_test_spec`/
`compute_lik_ratio_bootstrap_two_sided_pval` code path
(`inference_all_abstract_param_boot.R`), differing only in its
class-specific `shared()`/`get_likelihood_test_spec()`/
`simulate_under_lik_null()` overrides. On the exact same designs,
`InferenceContinOLS` shows near-nominal rejection rates (0.01–0.09) across
the board, while `InferenceContinLin` shows 0.17–0.41. This rules out the
generic bootstrap-LR machinery as the bug's location — it's in Lin's own
overrides (`inference_continuous_lin.R:285-429`, specifically `shared()`,
`build_lin_design_matrix()`, `get_centered_covariates()`,
`get_likelihood_test_spec()`, or `simulate_under_lik_null()`).

**2. Design-dependent, worsening with treatment/covariate structural
correlation.** For `compute_lik_ratio_bootstrap_two_sided_pval` on
`InferenceContinLin` (n≈200-400 per cell):
- `SPBR`: 0.059 (near nominal)
- `Bernoulli`: 0.186
- `FixediBCRD`: 0.172
- `FixedBlocking`: 0.186
- `FixedMatchingGreedy`: 0.406 (8× nominal)

Same pattern on `compute_param_bootstrap_pval` and
`compute_lik_ratio_bartlett_approx_two_sided_pval` (Bartlett: Bernoulli
0.128, SPBR 0.073, FixedBlocking 0.156, FixedMatchingGreedy 0.270). The
ordering tracks how strongly each design structurally links treatment
assignment to covariates (matching designs most, SPBR least) — consistent
with a bug in how Lin's covariate-centering/interaction-term machinery
interacts with a structured design, not with the generic bootstrap
mechanism itself.

**3. NOT reproduced in isolated small-scale manual tests.** Tried: plain
`DesignFixedBernoulli` with 1-3 random covariates (nominal, ~0-10% over
15-20 reps); and `DesignFixedBernoulli` with a genuine `W×X` interaction
baked into the DGP (still nominal, 5%/20). This means the bug is **not**
simply "w correlates with x" as a statistical property — it requires the
actual structured `Design` subclass (`FixedBlocking`/`FixedMatchingGreedy`/
etc.), not just a correlated covariate. No minimal repro using those
design classes directly has been constructed yet — **this is the concrete
next step.**

**4. One specific, unconfirmed lead:** `get_centered_covariates()`
(`inference_continuous_lin.R:262-284`) caches centered covariates on the
**design object's** private state (`des_priv$lin_centered_covariates`), not
the inference object's own cache — an unusual caching location for a
class-specific computation. The reused-worker parametric-bootstrap draw
loader (`inference_all_abstract_param_boot.R:932`,
`load_param_bootstrap_draw_into_worker`) does correctly null this out
per-draw, but `create_param_bootstrap_worker_state()`'s one-time setup does
not explicitly reset it (likely benign since it operates on a
freshly-duplicated design, but not verified). This is a plausible
contributor for the reused-worker path specifically but wouldn't by itself
explain the design-type-dependent pattern seen even outside the worker
path — worth checking, not confirmed as root cause.

## Scope

Isolated to `InferenceContinLin`, confirmed by direct comparison against
`InferenceContinOLS` on identical designs/methods (same generic machinery,
only `InferenceContinLin` shows the inflation). No other class has been
checked yet beyond this one comparison — TODO-2 below covers a broader
check.

## Progress 2026-09-23: sharper signal, still no working repro

A second investigation pass queried the historical CSV more finely — split
by `model_formula`/`design_formula`, not just by design type — for
`InferenceContinLin` × `FixedMatchingGreedy` ×
`compute_lik_ratio_bootstrap_two_sided_pval` at `beta_T=0` (same dataset,
`diamonds`, n=148, both rows):

| `model_formula` | `design_formula` | rejection rate | n |
|---|---|---|---|
| `~1` (no covariates) | `~.` | **0.00** | 50 |
| `~.` (all covariates) | `~.` | **0.88** | 50 |
| `~1` | `~1` | 0.105 | 19 |
| `~.` | `~1` | 0.526 | 19 |

Much sharper than "design-dependent" — driven specifically by covariate
adjustment. `~1` (Lin reduces to a plain mean-difference test) is actually
*conservative*; `~.` pulls in diamonds' full covariate set (`cut`/`color`/
`clarity` dummy-expand, `carat`/`x`/`y`/`z` near-collinear) and Lin's
`[1, W, Xc, W·Xc]` design matrix balloons to ~50 columns on n=148 — an
aggressive covariate-to-sample-size ratio, worse under a matched-pair
design that further reduces effective identifying variation. Working
hypothesis (NOT confirmed): a near-saturated/collinear covariate-
interaction design matrix under a matched-pair design destabilizes the
parametric-bootstrap null's residual-variance estimate.

Traced and partially cleared as a suspect:
`reduce_design_matrix_preserving_treatment`
(`inference_all_abstract.R:1122-1140`) and its cache-reuse path
`try_cached_reduced_design_keep` (`:1084-1120`) handle the rank-deficient-
column-dropping this large design matrix would need. The cache path DOES
re-validate rank (`qr(X_try)$rank != ncol(X_try)` at `:1114`) before
trusting any cached keep-set, falling through to a fresh QR reduction
otherwise — not an obvious stale-cache bug in the pattern this session's
other fixes addressed. Low confidence this is the culprit.

**Four serious repro attempts failed** — real `diamonds` dataset (via the
exact `_dataset_load.R` recipe), `DesignFixedMatchingGreedyPairSwitching`,
`model_formula = ~.`, `SD_NOISE = 0.1` per-subject noise (confirmed
per-row, not a shared shift, via `comprehensive_tests.R:834`'s
`apply_treatment_effect_and_noise()`). Tried: fresh random design+response
each rep; fixed design with response-only variation; realistic
diamond-price-derived `y` and pure noise. All four stayed near nominal
(0.00–0.07), never approaching the historical 0.88. Either the
reconstruction of the harness's exact per-rep mechanics still differs from
the real one in some undetected detail, or the effect is sensitive to the
specific collinearity pattern of the *particular* `diamonds_subset` draw
the historical run used (a fresh `slice_sample` each session gives
different exact collinearity), not reproducible from an independently-drawn
sample.

**Recommended next step, not yet attempted:** don't keep guessing the DGP
blind — re-run `comprehensive_tests.R` itself, scoped narrowly (class +
`lik_ratio` family filter, see TODO-1 below), with
`COMPREHENSIVE_DEBUG_RESAMPLING=1` (exists per `comprehensive_tests.R:809`)
to dump the exact `X_fit`, `keep`, `sig2`, and condition number at the
point of failure — gets the exact triggering instance directly instead of
re-guessing sampling seeds.

## TODOs

- [ ] TODO-1: Construct a minimal repro using the actual flagged `Design`
  subclasses (`DesignFixedBlocking`, `DesignFixedMatchingGreedy` — these
  showed the strongest signal) rather than a plain Bernoulli design with
  correlated covariates (already tried, did not reproduce). Confirm the
  constructor signatures and correct usage first (the investigation ran out
  of budget verifying `DesignFixedBlocking$new()`'s exact signature).
- [ ] TODO-2: With a working repro, trace `build_lin_design_matrix()` →
  `get_centered_covariates()` → `reduce_design_matrix_preserving_treatment()`
  (if that's the actual call chain — verify) → `shared()` step by step,
  comparing the observed fit's design matrix/column-reduction decisions
  against what `simulate_under_lik_null()` reuses for each bootstrap
  replicate. Suspect area: whether covariate centering or column-reduction
  is computed consistently between the design's actual block/match
  structure and what the null-simulated refits assume — a structured
  design's blocking/matching info feeding the observed fit but not (or
  differently) feeding the null-simulated refits would explain both the
  design-dependence (stronger design structure → bigger discrepancy) and
  the failure to reproduce with a merely-correlated-but-unstructured
  covariate (no actual block/match structure for the mismatch to bite on).
- [ ] TODO-3: Check the `get_centered_covariates()` design-object-cache lead
  (TODO from Finding 4 above) explicitly: does
  `create_param_bootstrap_worker_state()`'s one-time setup leave a stale
  `des_priv$lin_centered_covariates` that any bootstrap replicate might
  read instead of its own replicate's centering? Confirm or rule out.
- [ ] TODO-4: Once root-caused, check whether `InferenceContinLin`'s other
  methods (asymptotic Wald, its `rand`-family methods already fixed by
  `stale_worker_cache_resampling.md`) show any related distortion under
  the same structured designs, or whether this is isolated to the
  parametric-bootstrap/likelihood-ratio-simulation path specifically.
- [ ] TODO-5: Implement the fix once root-caused; verify via
  `pkgload::load_all(".", compile = FALSE)` only (hard project rule, see
  top-level `CLAUDE.md` — never `R CMD INSTALL`/`R CMD build`/
  `pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or unspecified
  `compile=`).
- [ ] TODO-6: Re-run the historical-CSV-style check (or a fresh, adequately
  powered simulation at the flagged designs — `FixedBlocking`,
  `FixedMatchingGreedy`, `Bernoulli`) and confirm rejection rates return to
  nominal (~5%) at `beta_T=0` across all three flagged methods.
- [ ] TODO-7: Regenerate the affected `comprehensive_tests` CSV rows for
  `InferenceContinLin`'s three flagged methods once fixed and installed,
  then re-run `audit_comprehensive_results.R --write-baseline` (only after
  install, not before — same caution as `stale_worker_cache_resampling.md`'s
  TODO-7).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. A
currently-correct class/design/method combination must not regress once
this is fixed (verify `InferenceContinOLS` and any other class sharing the
generic `ParametricLikelihoodBootstrap` machinery is unaffected by whatever
fix is applied, since the bug is confirmed isolated to `InferenceContinLin`'s
own overrides, not the shared machinery).
