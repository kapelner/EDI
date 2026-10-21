# Fix: `smoothed` Randomization-Bootstrap p-Value Adds Unclamped Continuous Noise to Binary/Ordinal Responses — Shared Machinery, ~85 Cells Wildly Miscalibrated

> **Implementation status (2026-10-07):** Smoothed BRT now rejects categorical
> or bounded model refits for incidence, ordinal, and proportion responses
> with a clear error directing callers to `type = "percentile"`. The p-value
> and CI type accessors omit `smoothed` for those classes, and lower-level
> supplied noisy draws are guarded before C++ or R refits. Real-valued
> location statistics such as `InferenceAllSimpleAverageDiff` remain supported
> on coded responses; its incidence p-value stays available, while the existing
> incidence CI guard keeps its CI unadvertised. Count, continuous, and survival
> behavior is unchanged. Focused CRAN tests passed 58 expectations with `pkgload::load_all(compile =
> FALSE)`. The historical audit findings below have not yet been rerun for
> calibration; do not interpret all ~85 cells as fixed by this support guard.

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-18`. Found 2026-09-23, surfaced by the new
> `pval_miscalibration` audit check — a `_smoothed` function-run variant
> appeared across 85 distinct (class, response_type) cells with wildly
> inconsistent miscalibration direction/severity (not a single consistent
> bias), which is itself the tell that this is shared machinery breaking
> differently depending on what data shape it's fed, not 85 independent
> per-class bugs. Root-caused same day. **Confirmed not yet tracked**:
> `ordinal_cumulative_link_null_refit_multistart.md:127-131` explicitly
> flags this exact `function_run` for `InferencePropOddsRegr` as "a
> separate, unexamined finding, out of scope for this plan."

## The bug, traced to a single shared function

`add_rand_bootstrap_smooth_noise()`
(`R/EDI/R/inference_all_abstract_rand_bootstrap.R:613-618`) is genuinely
shared machinery — one function, called from three sites in the abstract
base class (`:753`, `:928`, `:1060`), used identically by every class's
`type="smoothed"` randomization-bootstrap p-value variant. No class
overrides it (confirmed by grep).

```r
add_rand_bootstrap_smooth_noise = function(y, noise, response_type){
    y_noisy = as.numeric(y) + as.numeric(noise)
    if (identical(response_type, "count")) {
        return(pmax(0L, as.integer(round(y_noisy))))
    }
    y_noisy
}
```

The smoothing bandwidth is `bw = sd(private$y, na.rm = TRUE) / sqrt(n)`
(`:526-527`, `zero-one/proportion-unaware` — the marginal SD of the raw
coded response) and this Gaussian noise is added directly to the response
before refitting on each draw (`:753` et al. call
`add_rand_bootstrap_smooth_noise` with this per-draw `rnorm(n, 0, bw)`
noise). The function has an explicit special case for
`response_type == "count"` (rounds and floors at 0 — the code comment
above it, dated 2026-09-15, explains this was added because "a slightly
negative noisy count became a large negative integer after a nonzero-delta
shift, every Poisson/GLMM refit on that draw failed"). **There is no
equivalent handling for `"incidence"` (binary 0/1) or `"ordinal"`
(integer category codes)** — the comment literally says "Every other
response type keeps the raw additive noise." Continuous Gaussian noise
gets added straight onto 0/1 or 1/2/3/4-coded responses with no clamping,
producing invalid values like `y=0.3` or `y=4.7` fed into a refit that
expects binary/ordinal data.

**This directly explains the observed pattern**: downstream behavior on
malformed fractional-binary or fractional-ordinal input reasonably varies
wildly by each class's specific fitting internals (how it handles a
non-0/1 "binary" value, or a non-integer "ordinal" value, is undefined
behavior nobody designed for) — exactly matching what the audit found:
- `InferenceContinKKRobustRegrOneLik`: reject-rate 0.495 at a true null
  (should be ~0.05) — 10x inflated.
- `InferenceIncidKKCondLogitOneLik`: reject-rate 0.325 — 6.5x inflated.
- `InferenceOrdinalGCompMeanDiff`: reject-rate 0.000 — never rejects.
- The remaining ~80 cells span the full range between these extremes.

Note `InferenceContinKKRobustRegrOneLik` is `continuous` response type,
which is NOT one of the two flagged-as-missing cases (`incidence`/
`ordinal`) — continuous responses aren't bounded/discrete-coded the way
binary/ordinal are, so raw additive noise shouldn't be categorically wrong
for them the way it is for incidence/ordinal. This suggests the bug's
blast radius may be wider than just "binary/ordinal get corrupted inputs"
— TODO-2 below covers checking whether the bandwidth formula itself
(`sd(y)/sqrt(n)`) is appropriate across every response type/link scale, not
just whether integer/binary rounding is missing.

This bug is specific to classes that route through this R-level dispatch
— per the same code comment, "The C++ batch kernels (mean difference,
Wilcoxon, survival) apply `noise_mat` themselves; none of them fits an
integer-support likelihood, so they are unaffected" — so the affected-class
list is bounded to whichever classes use the generic R-level BRT smoothed
path, not every class with a `smoothed` variant. TODO-1 confirms the exact
boundary.

## Scope

Confirmed shared/generic (one function, three call sites, no per-class
override) — this is a systemic fix, not a per-class patch list, matching
the "single source of truth" pattern this session's other fixes have
favored. Not yet independently reproduced via a repeated-trial calibration
check (the investigating fork's time budget didn't cover it) — TODO-1
covers this.

## Historical options and implemented policy

**Option A — response-type-aware clamping, mirroring the `count` case.**
Add `incidence`/`ordinal` (and check `proportion`, which is also
bounded/non-continuous in spirit even though stored as a real number in
[0,1]) branches to `add_rand_bootstrap_smooth_noise()`: for `incidence`,
clamp/round to `{0,1}` (or reject noise draws that would flip the value,
depending on what's statistically appropriate for a smoothed *binary*
resampling distribution — needs thought, since rounding continuous noise
back to a binary value may defeat the entire point of "smoothing"); for
`ordinal`, round to the nearest valid integer level and clamp to the
observed category range.

**Option B — don't smooth binary/ordinal/proportion responses at all**,
i.e. `type="smoothed"` silently falls back to `type="percentile"` (or
errors/warns) for response types where continuous additive noise isn't a
coherent operation on the response scale. Simpler and safer, but removes a
feature (the whole point of `smoothed` is reducing null-distribution
discreteness, which matters MORE for exactly these low-cardinality
response types, so Option B trades away the feature where it would help
most).

Recommend investigating Option A's statistical validity first (does
clamped/rounded noise still deliver the discreteness-reduction benefit
`smoothed` exists for?) before falling back to Option B.

The implemented policy is an explicit unsupported error for categorical or
bounded model refits on incidence, ordinal, and proportion responses. It
avoids silently reporting an ordinary percentile result as `smoothed` and
avoids inventing a categorical transition kernel without calibration evidence.
Simple real-valued location statistics remain available because their
estimators accept the perturbed numeric response and the fast batch kernels
operate on that scale. Ordinal Ridit and Jonckheere-Terpstra remain unsupported:
their fast kernels already decline noisy draws, and the R fallback casts
continuous noise to integer category codes.

The actual dispatch is conditional: a concrete fast method runs only when it
accepts the draw and returns a distribution; otherwise the reusable or standard
R worker reaches `add_rand_bootstrap_smooth_noise()`. The source inventory shows
mean-difference and Wilcoxon kernels on real-valued statistics, plus continuous
OLS/robust and survival kernels. For categorical/bounded responses, the model
refit examples `InferenceIncidKKCondLogitOneLik`, `InferenceIncidProbitRegr`,
`InferenceOrdinalGCompMeanDiff`, and `InferencePropFractionalLogit` have no
accepted smoothed fast path; Ridit/Jonckheere have fast methods but explicitly
return `NULL` for noise. Mean difference on coded incidence/ordinal/proportion
remains supported, and ordinal SimpleWilcox has a numeric Wilcoxon path.
The checked-in `comprehensive_results_audit_baseline.csv` currently contains
25 smoothed p-value miscalibration rows (6 incidence, 3 ordinal, 0 proportion,
9 continuous, 7 count); this is only a subset of the historical ~85 cells, so
the full audit-to-dispatch cross-reference is still open.

## TODOs

- [ ] TODO-1: Confirm the exact boundary of affected classes — which
  concrete classes route through `add_rand_bootstrap_smooth_noise()`
  (R-level dispatch) vs. the C++ batch kernels (mean difference, Wilcoxon,
  survival — believed unaffected per the existing code comment, confirm
  this holds for `type="smoothed"` specifically, not just the general BRT
  path). Cross-reference against the ~85 flagged cells from the audit to
  build the exact list.
  **Source-boundary slice rechecked 2026-10-18:** exhaustive Trail search
  finds three application sites for the shared R noise hook: ordinary
  iteration, the reused-worker assignment loader, and the with-SE iteration.
  Both public p-value and CI entry points assert support for `type="smoothed"`;
  the corresponding type accessors omit it when unsupported. For
  `incidence`/`ordinal`/`proportion`, the current shared predicate permits
  only classes with `compute_fast_rand_bootstrap_distr`, excluding Ridit and
  Jonckheere-Terpstra; `continuous`/`count`/`survival` pass this categorical
  guard. The CI accessor also has its incidence-specific custom-statistic /
  compiled-kernel exception, so p-value and CI support must be cross-referenced
  separately. C++ batch paths apply their own `noise_mat`, rather than calling
  the R hook. This pins the mechanism boundary but does not map all historical
  flagged cells to supported/blocked branches. The current bandwidth remains
  `sd(private$y, na.rm = TRUE) / sqrt(n)` with no class- or response-specific
  adjustment in this audit; its appropriateness is still unvalidated, so no
  bandwidth change or calibration conclusion follows. No calibration or
  comprehensive-result outputs were read or changed.
  **Exact caller-edge audit, 2026-10-21:** Trail's caller graph confirms the
  three hook invocations and their enclosing functions:
  `load_rand_bootstrap_assignment_into_worker()`
  (`inference_all_abstract_rand_bootstrap.R:789`) uses the simulated
  response type; `run_rand_bootstrap_iteration_with_se()`
  (`inference_all_abstract_rand_bootstrap.R:960`) and
  `run_rand_bootstrap_iteration()` (`inference_all_abstract_rand_bootstrap.R:1092`)
  use the sub-design response type.
  Each calls the hook only when `draw[["smooth_noise"]]` is non-`NULL`; there
  is no fourth code caller. This sharpens the already-recorded mechanism
  boundary, but does not resolve the missing provenance-bearing historical
  audit rows or the remaining affected-cell cross-reference. No source, test,
  or result artifact changed.
  **Tracked-cell cross-reference, 2026-10-18:** the checked-in audit baseline
  has exactly 25 `_smoothed` p-value rows. Sixteen are in response types whose
  current p-value guard admits smoothing: continuous (9 keys: `InferenceAllSimpleAverageDiff`
  / `NA`, `InferenceAllSimpleMeanDiffPooledVar` / `NA`,
  `InferenceContinKKRobustRegrOneLik` / `~1`, `InferenceContinLin` / `~.` and
  `~1`, `InferenceContinOLS` / `~.` and `~1`, `InferenceContinQuantileRegr` /
  `~1`, `InferenceContinRobustRegr` / `~1`) and count (7 keys:
  `InferenceAllSimpleAverageDiff` / `NA`, `InferenceCountHurdleNegBin` /
  `~1`, `InferenceCountHurdlePoisson` / `~1`,
  `InferenceCountKKHurdlePoissonOneLik` / `~1`, `InferenceCountPoisson` /
  `~.`, `InferenceCountZeroInflatedNegBin` / `~1`, and
  `InferenceCountZeroInflatedPoisson` / `~1`). Current source identifies five
  of these as C++ batch dispatches: the two `InferenceAllSimpleAverageDiff`
  keys use the mean-difference kernel, the two `InferenceContinOLS` keys use
  the OLS kernel, and `InferenceContinRobustRegr` / `~1` uses the robust
  regression kernel. The other eleven use the generic R-level per-draw path;
  they remain admitted by the continuous/count response guard, but this is not
  evidence that their historical calibration finding is fixed.

  The other nine tracked keys are categorical and fail the current p-value
  support predicate because their classes have no accepted fast smoothed
  method: incidence `InferenceIncidBinomialIdentityRiskDiff` / `~.` and `~1`,
  `InferenceIncidKKCondLogitOneLik` / `~.` and `~1`, `InferenceIncidKKGEE` /
  `~.`, `InferenceIncidProbitRegr` / `~1`; ordinal
  `InferenceOrdinalGCompMeanDiff` / `NA`, `InferenceOrdinalPairedSignTest` /
  `NA`, and `InferenceOrdinalPropOddsRegr` / `NA`. These baseline records are
  historical audit findings, not evidence that current public calls can
  produce those rows. The remaining roughly 60 of the reported historical
  ~85 cells cannot be enumerated or assigned to dispatch branches from the
  tracked baseline: their exact (response, class, formula) keys are not checked
  in. Resolving that remainder requires the provenance-bearing historical
  audit input/output; no guessed rows or calibration inference are recorded.
- [ ] TODO-2: Investigate whether the bandwidth formula
  (`bw = sd(private$y) / sqrt(n)`, `:526-527`) is itself appropriate across
  every affected response type/link scale, not just whether rounding is
  missing — `InferenceContinKKRobustRegrOneLik` (continuous, reject=0.495)
  doesn't fit the "unclamped discrete noise" explanation cleanly and needs
  its own look. **Checked-in fixture audit 2026-10-16:**
  `R/EDI/tests/testthat/test-brt-smoothed-count-support.R` constructs one
  `n = 30` continuous KK design with `rnorm(n)` outcomes, runs the robust
  OneLik smoothed p-value once at `B = 21` (`use_rcpp = FALSE`), and asserts
  only that the result is finite. It does not estimate a null rejection
  rate, compare plain and smoothed p-values on matched draws, or vary the
  noise bandwidth. This fixture therefore confirms dispatch/execution, not
  the historical 0.495 rejection rate or whether `sd(y)/sqrt(n)` is
  appropriate. TODO-2 still needs a controlled empirical calibration; do
  not change the bandwidth based on the single-fixture smoke result.
  **Bounded installed-package pilot 2026-10-16:** ran 25 independent copies
  of that `n = 30` sharp-null fixture against installed EDI 1.0.3, with
  `B = 101` materialized assignments per copy. Each copy compared the
  percentile result with smoothed results using those same assignments and
  common Gaussian noise scaled to `0.5x`, `1x`, and `2x` the current
  `sd(y)/sqrt(n)` bandwidth. Rejection counts at 0.05 were respectively
  2/25 (0.08), 2/25 (0.08), 2/25 (0.08), and 1/25 (0.04); exact 95% binomial
  intervals are wide and include 0.05 in every case. The current-bandwidth
  result rejected exactly the same two fixtures as percentile; doubling the
  bandwidth changed one decision. This does not reproduce the historical
  0.495 rate or validate any bandwidth. Separately, the checked-in aggregate
  audit baseline reports the unsmoothed percentile and smoothed rows both at
  0.495 over 105 `beta_T = 0`, `model_formula = ~1` rows. **Historical row
  provenance audit 2026-10-16:** the baseline file was last committed in
  `11f61e0a` (2026-09-24); the ignored local raw CSV contains the matching
  105-row method cells (50 `FixedBinaryMatch` + 54 `KK21stepwise` on
  `diamonds`, plus 1 `FixedBinaryMatch` row on `pte_example`; raw timestamps
  2026-09-10 through 2026-09-16). Each method has 52/105 rejections, but
  equality of the rates does not mean equality of the p-values: 52 paired
  values match exactly, 53 differ, and only 2 rows have different rejection
  decisions. All 50 `diamonds`/`FixedBinaryMatch` p-values are exactly
  0.013245 for both methods. Thus the shared 0.495 is dominated by that
  design's 50/50 rejections and is not evidence that smoothing alone caused
  it. The harness calls the same `compute_rand_bootstrap_two_sided_pval()`
  method twice: default `type="percentile"`, then `type="smoothed"`
  (`R/package_tests/comprehensive_tests.R:3077-3092`). The raw CSV preserves
  outcomes and case/commit metadata, but has no RNG seed, assignments, or
  response vectors; it cannot regenerate the exact 105 historical inputs.
  The row-level outcomes can be paired for comparison, but an exact DGP replay
  is not reconstructible from checked-in/raw artifacts. Do not treat the
  earlier pilot as a historical replay or change bandwidth based on it.
  Raw and summary pilot outputs are isolated at
  `/tmp/edi-todo18-robust-onelik-bandwidth-20261016.csv` and
  `/tmp/edi-todo18-robust-onelik-bandwidth-20261016-summary.csv`; the script
  is `/tmp/edi_todo18_onelik_bandwidth_calibration_20261016.R`.
  **500-replicate extension 2026-10-16:** repeated the same predeclared
  n=30 KK14 sharp-null experiment against installed EDI 1.0.3, B=101, 500
  planned fixtures, common materialized assignments and common normal noise
  across the 0.5x/1x/2x bandwidth grid. Four fixtures (replicates 161, 171,
  269, 304) had a non-finite observed robust estimate, so all four variants
  were non-estimable there; the 496 finite replicates had zero thrown errors.
  Exact 95% binomial CIs were: percentile 35/496 = 7.06% [4.96%, 9.68%];
  smoothed at 0.5x, 33/496 = 6.65% [4.62%, 9.22%]; current 1x, 32/496 =
  6.45% [4.45%, 8.99%]; 2x, 22/496 = 4.44% [2.80%, 6.64%]. Paired decision
  discordances versus percentile were 4 (3 plain-only, 1 smoothed-only), 11
  (7, 4), and 19 (16, 3), respectively; exact paired binomial p-values were
  0.625, 0.549, and 0.00443. This suggests a detectable decision shift only
  at 2x in this small-n fixture; it does not justify choosing a new bandwidth.
  The 500-replicate raw, summary, and paired outputs are
  `/tmp/edi-todo18-robust-onelik-bandwidth-500-20261016.csv`,
  `/tmp/edi-todo18-robust-onelik-bandwidth-500-20261016-summary.csv`, and
  `/tmp/edi-todo18-robust-onelik-bandwidth-500-20261016-paired.csv`.
  Recomputed summaries and paired counts from all 2,000 raw rows match those
  CSVs exactly. The Rscript session printed all completion and summary output
  but exited nonzero with a trailing `unexpected ')'`; independent script
  parsing, R startup/shutdown, and summary-print checks pass, so this did not
  corrupt or invalidate the completed outputs (the exact source of the
  trailing process message is not reproducible). These remain installed-
  EDI-1.0.3 fixture evidence, not checkout validation or the unreconstructible
  historical DGP. **Representative larger-n/design slice 2026-10-16:** ran
  exactly `Rscript scratch/todo18_onelik_larger_n_20261016_01/calibrate.R`:
  installed EDI 1.0.3; `DesignFixedBinaryMatch`, n=148 (matching the
  historical diamonds fixed-match cell's row count), 50 sharp-null fixtures,
  B=101, and the same percentile/smoothed 0.5x/1x/2x paired assignment/noise
  grid. All 50 replicates were finite for every variant, with zero errors.
  Percentile rejected 1/50 = 2.0%, exact 95% CI [0.0005, 0.1065]; smoothed
  at 0.5x and current 1x each rejected 1/50 = 2.0% with the same interval;
  2x rejected 0/50 = 0%, CI [0, 0.0711]. Paired decisions were identical at
  0.5x and 1x (0 discordances); 2x differed on one replicate (plain-only),
  exact paired p=1. Thus this larger-n fixed-match null slice does not change
  the bandwidth decision: current 1x is indistinguishable from percentile,
  and the single 2x difference is uninformative. Raw, summary, and paired
  outputs are isolated under the gitignored
  `scratch/todo18_onelik_larger_n_20261016_01/`. This is a synthetic null
  fixture, not the unreconstructible historical DGP. TODO-2 remains open
  pending additional representative n/design slices and an evidence-based
  bandwidth decision.
  **Outcome-adaptive design slice 2026-10-16:** ran
  `Rscript scratch/todo18_onelik_kk21stepwise_20261016_01/calibrate.R`
  against installed EDI 1.0.3 only. This used 25 sharp-null fixtures with
  `DesignSeqOneByOneKK21stepwise` (n=60, two independent normal covariates,
  sequentially revealed independent N(0,1) responses), then
  `InferenceContinKKRobustRegrOneLik` (`model_formula=~1`, method MM,
  `use_rcpp=FALSE`). B=101 assignments were materialized once per fixture;
  percentile and smoothed at 0.5x/1x/2x current `sd(y)/sqrt(n)` bandwidths
  reused those assignments and common noise. All 25 fixtures were finite for
  all four variants, with zero errors. Percentile and smoothed 0.5x/current
  each rejected 2/25 (8%; exact 95% CI [0.0098, 0.2603]); 2x rejected 1/25
  (4%; [0.0010, 0.2035]). Paired decisions were identical at 0.5x and 1x;
  the 2x result differed on one fixture (percentile-only, exact paired
  p=1). This adds an outcome-adaptive design check but is still a small,
  synthetic installed-package diagnostic, not a historical-DGP replay or
  checkout validation; it does not justify changing the bandwidth. Raw,
  summary, paired results, and the predeclared seed protocol are isolated in
  `scratch/todo18_onelik_kk21stepwise_20261016_01/`. TODO-2 remains open.
  **Retained-artifact/provenance recheck, 2026-10-21:** the only retained
  calibration outputs found are the two exploratory B=101 robust-OneLik
  slices above: FixedBinaryMatch (n=148, 50 fixtures; 200 variant rows) and
  KK21stepwise (n=60, 25 fixtures; 100 variant rows). Both were run against
  installed EDI 1.0.3 and retain deterministic seed/variant data, but neither
  records the installed package path, EDI DLL hash, R version, checkout HEAD
  or source hash, or a run-provenance sidecar. Their raw-output SHA-256 values
  are `623fe2f22bd123eca1a8b58f0a3f189ac097d46e60912285ea395610b33dd59d`
  and `e46b1a8688d37135753430f2b0e776b3dfbcccfed98096affc5fe53881b90e71`,
  respectively; these identify retained exploratory files, not accepted
  current-source calibration. The earlier n=30/25-fixture and 500-fixture
  pilot outputs formerly recorded under `/tmp/edi-todo18-*` are absent; their
  historical summaries in this plan are not recoverable raw evidence. The
  comprehensive audit baseline remains the 2026-09-24 snapshot at
  `11f61e0a`, while the large local comprehensive CSVs have no seed,
  assignment, or response-vector fields for exact replay. Thus no retained
  artifact meets TODO-6/7 calibration acceptance. Before a new run, the
  maintainer must still select the admitted roster/strata and null DGP,
  define the per-cell versus simultaneous acceptance rule (including any
  multiplicity treatment), choose interval confidence level and attempted
  versus estimable denominator, and confirm the proposed precision target
  (at least 500 estimable cases per stratum, B=101) or replace it. Preserve
  the full post-fix installed-package calibration and provenance-stamped
  comprehensive regeneration gates; no result is accepted by this audit.
  **Bounded on-disk recheck, 2026-10-21:** both named exploratory raw pilot
  files are present in the repository's `scratch/` tree:
  `scratch/todo18_onelik_larger_n_20261016_01/raw.csv` (200 data rows; SHA-256
  `623fe2f22bd123eca1a8b58f0a3f189ac097d46e60912285ea395610b33dd59d`) and
  `scratch/todo18_onelik_kk21stepwise_20261016_01/raw.csv` (100 data rows;
  SHA-256 `e46b1a8688d37135753430f2b0e776b3dfbcccfed98096affc5fe53881b90e71`).
  Their companion summaries and paired tables are present (four summary rows
  and three paired comparisons per slice). Raw schemas retain covariate,
  design, outcome, assignment, noise, and fit seeds and identify installed
  EDI 1.0.3, but provide no package path, DLL hash, R version, checkout HEAD,
  source hash, or provenance sidecar. The specifically named earlier
  `/tmp/edi-todo18-robust-onelik-bandwidth-20261016*` raw/summary outputs are
  absent. These files corroborate only the two small synthetic pilot
  summaries, not the historical 105-row replay or post-fix calibration.
  Repository evidence still cannot choose nine versus 16 supported
  calibration cells, their null DGP/strata, per-cell versus simultaneous
  acceptance and multiplicity, interval confidence level, attempted-versus-
  estimable denominator, or the proposed precision target; the historical
  audit's exact seeds, assignments, and response vectors also remain
  unavailable. No simulation, build/install, or canonical result write was
  performed.
  **Source-only bandwidth consistency audit, 2026-10-20:** the standalone
  p-value path (`inference_all_abstract_rand_bootstrap.R:555-558`) and the
  CI-inversion path (`inference_all_abstract_rand_bootstrap_ci.R:244-248`)
  independently use the same raw-response rule,
  `sd(private$y, na.rm = TRUE) / sqrt(n)`, falling back to `1 / sqrt(n)`
  when the sample SD is non-finite or nonpositive. Both attach one Gaussian
  noise vector per draw before the null shift. The shared noise application
  (`inference_all_abstract_rand_bootstrap.R:641-646`) leaves continuous and
  survival values additive on their observed scale and rounds/floors counts
  afterward; there is no class- or response-specific bandwidth or
  transform-scale conversion. This rules out a p-value-vs-CI formula
  discrepancy, but does not establish that one raw-scale bandwidth is
  appropriate across these response families, nor explain the historical
  continuous KK robust OneLik finding. A bandwidth decision still needs
  predeclared calibration across representative supported response/design
  strata; the existing small matched-grid pilots are not enough to choose a
  new multiplier. No source or test was changed in this audit.
- [ ] TODO-3: Reproduce directly via `pkgload::load_all(".", compile = FALSE)`
  only (never `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project rule,
  top-level `CLAUDE.md`). Pick 2-3 of the worst-offending classes, run a
  repeated-trial true-null calibration check on `type="smoothed"`, and
  confirm the wild miscalibration reproduces. Compare against the plain
  (non-smoothed) variant on the same draws to isolate the smoothing step
  specifically.
  Bounded fixtures for the historical incidence KK conditional-logit and
  ordinal GComp classes now confirm their smoothed p-values reject before any
  refit. The historical continuous KK robust OneLik class remains supported
  and returned a finite smoothed p-value (B = 21). These are dispatch checks,
  not repeated-trial calibration or reproduction of the reported rates.
- [x] TODO-4: Decide Option A vs. B (per response type, possibly a mix —
  e.g. Option A for `incidence`/`ordinal`, investigate `proportion`
  separately, Option B only if A proves statistically unsound for a given
  type) and implement.
- [x] TODO-5: Verify the fix doesn't change `smoothed` results for
  response types that were already correctly handled (`count`, and
  whichever of `continuous`/`survival` turn out fine) — bit-for-bit or
  within floating-point tolerance for those.
  The numeric noise transformation and estimator paths for these response
  types have no code changes; the new guard returns immediately for all three.
  Focused tests verified count rounding/flooring and a finite smoothed Poisson
  GLMM p-value, continuous raw additive noise and a finite KK robust OneLik
  smoothed p-value, plus survival raw additive noise and a finite CoxPH
  smoothed p-value (all with `compile = FALSE`). This establishes path
  preservation, not calibration of the continuous outlier. The deterministic
  count-support reference is `R/EDI/tests/testthat/test-brt-smoothed-count-support.R`:
  input `y = c(0, 0, 1, 3, 7)` and noise `c(-0.9, 0.4, -0.6, 0.51, -2.7)` must
  return integer `c(0, 0, 0, 4, 4)`, with every value nonnegative; this
  independently pins both nearest-integer rounding and the zero floor,
  including negative noisy counts. The same test asserts the continuous path
  remains exactly `y + noise`, and the Poisson GLMM public-path check produces
  a finite p-value without GLMM fit-error messages. Categorical/bounded
  response guards and lower-level supplied-draw guards are pinned in the same
  file. These deterministic contracts are covered; they do not substitute for
  the open historical/true-null calibration or CSV regeneration gates.
- [ ] TODO-6: Re-run true-null calibration checks across all affected
  classes/response-types and confirm rejection rates return to nominal
  ~5%.
- [ ] TODO-7: Add a permanent regression test analogous to this session's
  other new coverage: construct a minimal true-null fixture per affected
  response type, run `type="smoothed"` repeatedly, and assert calibration
  stays within a reasonable band of nominal — this general shape
  (response-type-dependent noise validity) isn't caught by the existing
  non-degeneracy test either.
  A focused support regression now covers the public p-value and CI guards,
  advertised types, lower-level draws, and the preserved real-valued/count
  paths; repeated-trial calibration remains open.
  **Acceptance inputs still required:** before a calibration regression can
  be made deterministic, the maintainer must specify (1) the per-cell nominal-
  rejection acceptance interval or exact-binomial pass rule, (2) the supported
  response/class/design strata and true-null fixture for each cell, and (3)
  the replicate-count or precision target, including whether the rule is
  applied independently per cell or simultaneously across cells. The existing
  plan's phrase “reasonable band” and its historical flagged rows do not
  select these inputs; no threshold or pilot-derived substitute is assumed.
  After the user's 2026-10-14 reinstall, `test-brt-smoothed-count-support.R`
  passed 58 assertions and `test-brt-smoothed-noise-mat-plumbing.R` passed 7
  against the installed package; these validate the guard/plumbing, not the
  still-open calibration TODOs.
  **Current-R-source regression recheck (2026-10-18):** after
  `pkgload::load_all("R/EDI", compile = FALSE)`,
  `test-brt-smoothed-count-support.R` passed 58 assertions and
  `test-brt-smoothed-noise-mat-plumbing.R` passed 7 (65 total, no failures,
  warnings, or skips). The source came from
  `/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3. The already-built
  native DLL used by the source overlay was
  `/tmp/RtmpbRBDJL/pkgload36fbdb21f8fda4/EDI.so`, SHA-256
  `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`
  (matching installed EDI 1.0.3). This validates current R smoothing support
  guards, count round/floor behavior, and native noise-matrix plumbing against
  the existing DLL ABI. It does not measure repeated-trial calibration or
  validate the native source checkout; TODO-6/7 calibration and TODO-8
  comprehensive regeneration remain open. No benchmark, build/install, or
  canonical result write occurred.
  **Historical-class CI guard regression (2026-10-20):** the existing
  `test-brt-smoothed-count-support.R` fixture now also verifies that
  `InferenceIncidKKCondLogitOneLik` and `InferenceOrdinalGCompMeanDiff` omit
  `smoothed` from CI support and reject a smoothed CI request before draws,
  complementing their existing p-value checks. With
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`, the focused
  `testthat::test_file("R/EDI/tests/testthat/test-brt-smoothed-count-support.R")`
  passed 62 expectations (0 failures, warnings, or skips). R was
  `R Under development (unstable) (2026-10-13 r90668)`, source was
  `/home/kapelner/workspace/EDI/R/EDI` (version 1.0.3), and the already-built
  overlay DLL `/tmp/RtmpcEE3Yy/pkgload7cb1c37f62ab2/EDI.so` had SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  The test file SHA-256 was
  `a9f60a6a4e98bb1180478b54a6a1bff5cad567f7ecad70f754dc725dd062b391`.
  This deterministic guard coverage does not close the owner-defined
  calibration or post-install regeneration gates; no native source validation
  or canonical result write occurred.
  **Installed-package guard recheck (2026-10-20):**
  `Rscript -e 'library(EDI); testthat::test_file("R/EDI/tests/testthat/test-brt-smoothed-count-support.R", reporter = "summary")'`
  passed 62 expectations against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had
  SHA-256 `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (MD5 `a75519a9256c0b3121398032314291d4`). It covers count support,
  bounded/categorical model-refit rejection, and supported real-valued
  paths; these are deterministic guard checks, not calibration or historical
  reproduction. TODO-6/7 calibration, historical audit provenance, the
  bandwidth investigation, and TODO-8 comprehensive regeneration remain open.
  No build/install or canonical result write occurred.
  **Latest installed-artifact support recheck, 2026-10-21:** reran
  `test-brt-smoothed-count-support.R` via `timeout 180s Rscript -e` after
  `library(EDI)`; all 68 expectations passed (0 failures, warnings, or skips).
  Installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` loaded DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`), byte-identical to the ignored
  checkout `R/EDI/src/EDI.so`. The test file SHA-256 was
  `67d7af1b25207cf62f21a5f64c212abae4a4d047dece86b4be9674193d165126`.
  This checks deterministic support/guard behavior on that installed
  artifact only; it does not validate current R-source identity, calibration,
  historical findings, the bandwidth choice, or comprehensive rows. No
  build/install or canonical output occurred.
- [ ] TODO-8: Regenerate the affected `comprehensive_tests` CSV rows for
  the confirmed affected classes' `smoothed` variant once fixed and
  installed (only after install, not before, same caution as the sibling
  plans this session produced).
  **Existing-artifact audit 2026-10-16:** no artifact closes this gate.
  Checked-in `comprehensive_results_audit_baseline.csv` is last committed at
  `11f61e0a` (2026-09-24). The ignored raw comprehensive CSVs have local mtimes
  from 2026-09-27 (count) and 2026-10-09 (continuous/incidence/ordinal), but
  no source-SHA/package-library provenance tying their rows to the corrected
  code; their timestamps alone are not accepted as a post-fix regeneration.
  The successful full coverage CI run `38808821546` used commit
  `430c19bcdb0702d998c79f9058c449449034134c` and exposed 103 artifacts; the
  complete artifact-name list consists only of `coverage-merged`,
  `coverage-registry`, and `coverage-shard-*`, not simulation results. The
  later scheduled coverage run `38862282598` on the same commit skipped its
  plan, shard, and merge jobs. The `430c19bc` pre-push regeneration commit
  changed only `comprehensive_suite_internal_surfaces.csv`. TODO-56's local
  snapshot is a copy of the old comprehensive CSVs and its rerun targets
  ModifiedPoisson, not these smoothed cells. A provenance-recorded,
  post-install TODO-18 rerun and verified output rows are still required.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
Response types NOT affected by whatever gap is found must produce
unchanged (bit-for-bit or floating-point-tolerance) results after the fix.

## Audit boundary and next criterion (2026-10-16)

The historical `InferenceContinKKRobustRegrOneLik` 49.5% signal is a
continuous-response/bandwidth question, not explained by the categorical
noise-support bug: in the paired historical rows the unsmoothed percentile
variant also rejected 52/105, exactly the smoothed count; only 2/105
decisions differed, and all 50 `diamonds`/`FixedBinaryMatch` rows rejected
under both at p = 0.013245. The raw rows lack seeds, assignments, and response
vectors, so they cannot recover the original DGP. Existing installed-1.0.3
follow-ups (500 `n=30` KK14 cases, 50 `n=148` FixedBinaryMatch cases, and 25
KK21stepwise cases) show no current-bandwidth rejection-rate difference from
matched percentile draws; none is an exact historical replay or validates
the checkout.

Keep the nearby release findings separate: TODO-17 is the Wilcoxon
inclusive-tail/zero-estimate tie boundary (a generic mid-p change would alter
legitimate tied results); TODO-20 is Quantile regression's nonsmoothed BRT
duplicate-row/fit sensitivity. Neither is evidence about adding Gaussian
noise to response values in this plan.

Next runnable criterion after TODO-56 is terminal: the categorical/bounded
model-refit cells (incidence, ordinal, proportion) are now intentionally
unsupported and should be checked as rejection/advertisement guards, not
recalibrated as if they still had a smoothed estimator. For the remaining
supported outliers, include both continuous and count cells. The checked-in
smoothed `pval_miscalibration` baseline has seven count keys in addition to
the continuous keys: `InferenceAllSimpleAverageDiff`,
`InferenceCountHurdleNegBin` (`~1`),
`InferenceCountHurdlePoisson` (`~1`),
`InferenceCountKKHurdlePoissonOneLik` (`~1`), `InferenceCountPoisson` (`~.`),
`InferenceCountZeroInflatedNegBin` (`~1`), and
`InferenceCountZeroInflatedPoisson` (`~1`). These are still supported after
the count rounding/floor correction, so the deterministic boundary test does
not close their empirical calibration gate. Run a predeclared true-null
comparison for the continuous outliers, including
`InferenceContinKKRobustRegrOneLik` (`model_formula=~1`) and
`InferenceContinOLS` (`model_formula=~.`), using the comprehensive harness's
current null DGP/design once recovered; cover the seven count keys above in
the same audit or an equivalent predeclared count stratum. Use at least 500
estimable outer cases and B=101 materialized assignments per case. Reuse the
same assignments and Gaussian noise in percentile and smoothed variants;
report non-estimable counts, exact binomial intervals for each rejection
rate, and paired decision discordances. If the comprehensive DGP cannot be
reconstructed, label this as a fresh representative calibration only; do
not claim it reproduces the historical cells or alter the bandwidth from
it. The focused deterministic support test already pins the count transform;
do not add a nominal-rate assertion to it before this empirical run defines
the fixture, seed, and acceptance tolerance.
