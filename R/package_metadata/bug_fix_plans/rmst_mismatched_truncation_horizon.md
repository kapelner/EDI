# Fix: `InferenceSurvivalRestrictedMeanDiff` Computes Restricted Mean Survival Time to a Different Truncation Horizon τ Per Arm

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-23`. Found 2026-09-24, surfaced by the new
> `low_coverage` audit check's two-sided exact-binomial test (H0:
> coverage = 0.95) — near-universal, severe undercoverage (0.53-0.65,
> should be 0.95) across almost every CI-construction method family this
> class supports; root-caused same day.

## The bug, confirmed by direct code reading at three sites

Restricted Mean Survival Time (RMST) integrates the Kaplan-Meier curve
from 0 to a truncation horizon τ. The RMST literature (Royston & Parmar
2013, and this class's own cited reference) is explicit that τ **must be
common across the two arms being compared** — otherwise the difference of
two RMSTs integrated to different horizons is not a coherent, comparable
estimand. This class computes τ **independently per arm**, as that arm's
own maximum observed/censored time, at three sites that all share the
same shape:

- R level: `weighted_survival_stat_for_group()`
  (`R/EDI/R/inference_survival_rmst.R:239`) — `tau = max(y)`, called
  separately per arm by `weighted_survival_stat_diff()` (`:257`/`:260`).
- C++ point-estimate level (the actual production path,
  `get_survival_stat_diff`): `fast_survival_stats.cpp:158` and `:290` —
  `restricted_mean += survival_probs.back() * (subjects.back().time -
  unique_times.back())`, where `subjects` is that call's own per-group
  vector, sorted, so `subjects.back().time` is that arm's own max time.
- C++ SE level: `fast_survival_stats.cpp:400`,
  `get_restricted_mean_se_for_group()` — `double tau =
  subjects.back().time;`, the identical per-arm-local pattern, feeding
  `get_restricted_mean_se_diff()` (`:455`, calling the per-group SE
  function once per arm at `:487`/`:489`).

At this harness's 15% censoring rate (`comprehensive_tests.R:798` — a
moderate, unremarkable rate, not an edge case), the two arms routinely
realize different max follow-up times, so this fires broadly rather than
in a rare corner case — exactly matching the observed near-universal (not
occasional) undercoverage.

## Two distinct downstream consequences, both plausible contributors

1. **Estimand bias.** The point estimate is a difference of two RMSTs
   integrated to *different* horizons — not an unbiased estimate of any
   single well-defined quantity tied to `beta_T`.
2. **Structurally under-estimated SE.** τ varies draw-to-draw (a
   different bootstrap resample realizes a different max time, so a
   different τ), an extra source of sampling variability the classical
   Greenwood-based SE formula — which assumes a *fixed* τ — never
   accounts for. This alone would produce the observed undercoverage
   signature regardless of the bias question.

This also explains the exact pattern observed: consistent, severe
undercoverage across `wald` (0.535), `asymp` (0.569), `subsampling`
(0.562), every `bayesian_bootstrap`/`bootstrap` flavor (0.565-0.601),
`m_out_of_n_bootstrap` (0.591), and `jackknife_wald` (0.645) — all of
which reuse the same core `get_survival_stat_diff`/
`get_restricted_mean_se_diff` machinery — while `rand_bootstrap`-family
variants (0.857-0.937) and `rand(custom)` (0.971) are comparatively
spared, since they route through a structurally different resampling
mechanism (`compute_fast_rand_bootstrap_distr`,
`inference_survival_rmst.R:204-218`, not traced in detail here but
evidently not sharing the per-arm-τ code path).

## Full per-`function_run` coverage breakdown (n ≥ 30, historical CSV)

| `function_run` | n | coverage |
|---|---:|---:|
| `compute_wald_confidence_interval` | 1448 | 0.535 |
| `compute_asymp_confidence_interval` | 1586 | 0.569 |
| `compute_subsampling_confidence_interval` | 906 | 0.562 |
| `compute_bayesian_bootstrap_confidence_interval_bca` | 1232 | 0.565 |
| `compute_bayesian_bootstrap_confidence_interval_wald` | 1556 | 0.568 |
| `compute_bayesian_bootstrap_confidence_interval` | 738 | 0.572 |
| `compute_bayesian_bootstrap_confidence_interval_basic` | 738 | 0.574 |
| `compute_bootstrap_confidence_interval` | 738 | 0.572 |
| `compute_bootstrap_confidence_interval_bca` | ~900 | ~0.58 |
| `compute_bootstrap_confidence_interval_basic` | ~900 | ~0.58 |
| `compute_m_out_of_n_bootstrap_confidence_interval` | 906 | 0.591 |
| `compute_bootstrap_confidence_interval_studentized` | 173 | 0.601 |
| `compute_jackknife_wald_confidence_interval` | 1567 | 0.645 |
| `compute_rand_bootstrap_confidence_interval*` (several variants) | — | 0.857-0.937 |
| `compute_rand_two_sided_pval(custom)` (CI-adjacent, for reference) | — | 0.971 |

This class has no `model_formula` concept (`formula` column is `NA`
throughout — confirmed). `coverage_truth` is 100% populated, ruling out a
missing-truth-target explanation for the pattern.

## Proposed fix — not yet applied

Compute a single shared τ once per estimation call — the standard
convention is the **minimum** of the two arms' max observed/censored time
(the horizon both arms can actually support) — and pass it into both
arms' KM-integration and SE computation instead of each independently
deriving its own from `subjects.back().time`. This touches exactly three
sites: `weighted_survival_stat_for_group()`
(`inference_survival_rmst.R:239`) and the two C++ functions
(`fast_survival_stats.cpp:158`/`:290` for the point estimate, `:400` for
the SE). Not a "pick a more robust estimator" design decision — this is a
concrete, scoped code fix, not an inherent statistical limitation of RMST.

## TODOs

- [ ] TODO-1: Confirm the mechanism with a direct reproduction via
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
  Construct a minimal two-arm fixture where the arms' realized max times
  differ by a known amount, print each arm's independently-derived τ, and
  confirm they differ as predicted. This investigation traced the code but
  did not run it — this is the concrete next step before treating the
  root cause as fully closed.
- [ ] TODO-2: Implement the shared-τ fix at the three identified sites
  (`weighted_survival_stat_for_group()`,
  `fast_survival_stats.cpp:158`/`:290`, `fast_survival_stats.cpp:400`).
  Since the point estimate itself changes (not just its SE), this is a
  **documented default change** requiring a numerical-equivalence
  discipline different from most of this session's other fixes — a class
  whose two arms happen to share max follow-up time (rare but possible)
  should show no change; every other case will show a genuinely different
  point estimate, by design (the old value was not a well-defined
  estimand). Note this explicitly in the fix's commit message and any
  migration-golden test updates.
- [ ] TODO-3: Requires C++ changes (`fast_survival_stats.cpp`) — per
  top-level `CLAUDE.md`, verify via targeted compile of only the touched
  `.cpp` file(s), never a full package rebuild. Confirm this rule applies
  and follow it exactly when implementing TODO-2.
- [ ] TODO-4: Decide the exact shared-τ convention (minimum of both arms'
  max time is the standard literature default; confirm this is what's
  wanted here, or whether a pre-specified fixed horizon parameter should
  be exposed instead — check whether the class already has a `tau`/
  horizon argument that's simply unused, or whether one needs to be
  added).
- [ ] TODO-5: Re-run the historical-CSV-style coverage check (or a fresh
  simulation at this harness's censoring rate) across every affected
  method family and confirm coverage returns to nominal ~95%.
- [ ] TODO-6: Add a permanent regression test constructing a fixture with
  deliberately mismatched arm-level max follow-up times, asserting the
  point estimate and SE are computed against one shared τ, not two
  different ones.
- [ ] TODO-7: Regenerate the affected `comprehensive_tests` CSV rows for
  this class's coverage-affected methods once fixed and installed (only
  after install, not before, same caution as the sibling plans this
  session produced).

## `InferenceSurvivalDepCensTransformRegr` — separate, narrower, unconfirmed finding

Surfaced by the same audit sweep, this class shows a narrow, isolated
undercoverage symptom — only
`compute_bayesian_bootstrap_confidence_interval_basic` (0.55 at n=202,
0.74 at n=124), while every other method family (`wald`, `asymp`,
`score`, `gradient`, `param_bootstrap`, `lik_ratio*`,
`rand_bootstrap*`) is near-nominal (0.91-1.00), including the plain and
`wald`-variant Bayesian-bootstrap CIs for the *same* class. Not the same
shape as the RMST finding above (narrow vs. broad), and not yet
root-caused: no `compute_bayesian_bootstrap_confidence_interval_basic`
override exists in `inference_survival_dep_cens_transform.R` (confirmed by
grep), so it resolves to shared Bayesian-bootstrap mixin machinery not yet
traced. The class's own file already documents a *different*,
previously-fixed crash bug in the sibling `compute_bootstrap_confidence_interval_basic`/
`_bca` methods ("never-implemented `_basic`/`_bca` name variants always
threw `attempt to apply non-function`," `:179-191`) — worth checking
whether the Bayesian-bootstrap `_basic` variant has an analogous, still-
unfixed dispatch gap; that's the concrete next step, not yet done.

**Cross-validation, 2026-09-24**: a fresh full-package audit run
surfaced 4 findings for this class (not yet the full picture, more
`function_run`s than the single `_basic` one above): `compute_bayesian_bootstrap_confidence_interval_wald`
OVER-coverage (1.000 at n=124, 0.995 at n=202), plain
`compute_bayesian_bootstrap_confidence_interval` UNDER-coverage (0.832 at
n=202 — this may be the same signal as the `_basic` finding above,
different variant), and `compute_rand_bootstrap_confidence_interval_smoothed`
OVER-coverage (1.000 at n=137). The mix of both directions (over AND
under, across different Bayesian-bootstrap CI-formula variants for the
SAME underlying estimate) argues against a single simple explanation and
for something variant-specific in how each CI formula reads the shared
bootstrap distribution — consistent with, but not proof of, the
suspected `_basic`-style dispatch-gap hypothesis above. Not further
investigated this pass; the RMST fix (TODO-1..7 above) is unrelated to
this class (`DepCensTransformRegr` doesn't use RMST) and should proceed
independently.

- [x] TODO-8 (2026-09-24, done — refuted as originally framed): Traced the
  dispatch. `compute_bayesian_bootstrap_confidence_interval()`
  (`inference_all_abstract_bayesian_bootstrap.R:404-489`) is a **single
  shared method** dispatching internally on a `type=` parameter
  (`"percentile"`/`"basic"`/`"wald"`/`"studentized"`/`"bca"`), not a set
  of separately-named `_basic`/`_wald`/etc. methods — unlike the plain
  (non-Bayesian) bootstrap family, where `_basic`/`_bca` really were
  distinct, previously-unimplemented method names. So there is no
  analogous "missing method" dispatch gap to find here; the `_basic`
  suffix in `comprehensive_tests.R`'s `function_run` naming is the
  harness's own convention for `type="basic"`, not a real second method.
  The `"basic"` type falls through to the generic
  `ci_from_boot_distribution()` (`inference_all_abstract_non_param_boot.R:1700-1705`)
  → `bootstrap_ci_from_distribution()` — **the same shared `"basic"`
  CI-formula helper already confirmed defective for HL-ties-at-zero data
  in `simple_wilcox_hl_degenerate_pval_boundary.md`'s `TODO-1`**. This
  class has no HL-tie mechanism (it's a survival transform-regression
  estimator, not a rank-based one), so that specific tie-driven defect
  doesn't directly transfer — but it raises the real possibility that
  `bootstrap_ci_from_distribution()`'s `"basic"` formula has a broader,
  non-tie-specific defect that both classes are independently exposing.
  Not confirmed either way for this class.
- [x] TODO-9 (2026-09-24, done — refuted): read
  `bootstrap_ci_from_distribution()` (`helper_bootstrap_ci.R:5-22`) in
  full. **No code-level defect** — the `"basic"` branch
  (`2 * est - stats::quantile(boot_distr, probs = c(1 - alpha/2,
  alpha/2), type = 8)`) matches the textbook basic/reflection-bootstrap
  formula exactly: quantile probs are ordered `(1-alpha/2, alpha/2)`
  (high then low), so `2*est` minus each, in that order, yields
  `(lower, upper)` correctly. No swapped order, no off-by-one, `type = 8`
  (a defensible, commonly-recommended quantile type) is used
  consistently. Does **not** explain the Wilcox/MeanDiffPooledVar
  findings — this rules out a shared-formula bug as their common cause;
  those remain explained by their own already-confirmed, independent
  mechanisms (`TODO-1`/`TODO-2` in `simple_wilcox_hl_degenerate_pval_boundary.md`).
  **Correction to this file's own "Cross-validation" note above**: the
  plain, unsuffixed `compute_bayesian_bootstrap_confidence_interval`
  function_run does **not** call `type="basic"` — traced its dispatch
  (`inference_all_abstract_bayesian_bootstrap.R:404-489`,
  `type = tolower(type %||% "percentile")`) and its harness call site
  (`comprehensive_tests.R:2698`, no `type=` argument passed) — it
  defaults to `type="percentile"`, a *different* CI-formula branch
  entirely (raw `quantile(boot_distr, probs=c(alpha/2, 1-alpha/2))`, no
  reflection). So the fresh audit's 0.832-under-coverage finding for the
  plain function_run is on the **percentile** method, not `"basic"` —
  update any downstream reasoning accordingly; only the harness's
  explicit `_basic`-suffixed `function_run` (`bayes_ci_type="basic"` at
  `comprehensive_tests.R:2700-2701`, a separate historical-baseline entry
  at 0.55/0.74 coverage, not re-confirmed this pass) actually exercises
  the `"basic"` branch.
  **Root cause is the shape of this class's own bootstrap distribution,
  not a code defect**: the observed pattern — `percentile`/`"basic"`
  both undercover, `wald` (symmetric, SD-based, ignores boot_distr's
  actual shape) overcovers on the SAME underlying estimate/distribution —
  is the textbook signature of a skewed or biased-mean bootstrap
  distribution: quantile-based methods (percentile, basic/reflection)
  are known to perform poorly (typically undercovering on the skewed
  side) under skew, while a symmetric normal-approximation method using
  only the SD is comparatively insensitive to that skew and instead
  tends to over-cover if the SD is inflated by the same asymmetry/heavy
  tail. This is a **known methodological weakness of the basic/
  percentile bootstrap under a skewed sampling distribution**, not a
  bug in `bootstrap_ci_from_distribution()` or in `DepCensTransformRegr`'s
  estimate. Not independently confirmed via a direct skewness
  measurement of this class's actual `boot_distr` (would need a
  standalone repro) — recommend closing this as accepted/documented
  behavior unless someone measures the skewness directly and it turns
  out to be mild (which would reopen the question). **Not added to
  `release_v1_5_0.md`** — no code defect confirmed, and the
  methodological-weakness explanation, if it holds, isn't something a
  one-line fix addresses (the enhancement would be "prefer BCa/
  studentized over basic/percentile for skew-prone estimators," a
  design decision, not a bug fix — worth a separate, lower-priority
  enhancement note if the skewness is later confirmed, not a v1.5.0 item
  now).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only for R-layer checks, and
only a targeted compile of touched `.cpp` files (never a full build) once
the C++ fix (TODO-2/3) is implemented. Unlike most of this session's other
fixes, TODO-2 is an intentional, documented default change to the point
estimate for classes whose arms have mismatched follow-up — this is
restoring a well-defined estimand, not introducing a new opt-in switch,
but it is NOT expected to be bit-for-bit-preserving the way this
session's other fixes were, and that distinction should be called out
explicitly wherever this fix is described.
